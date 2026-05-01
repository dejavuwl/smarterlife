use std::{
    collections::{HashMap, HashSet},
    sync::Arc,
    time::Instant,
};

use anyhow::{anyhow, Context, Result};
use axum::{
    extract::{Request, State},
    http::{header, HeaderMap},
    middleware::Next,
    response::Response,
};
use jsonwebtoken::{decode, decode_header, Algorithm, DecodingKey, Validation};
use reqwest::Client;
use serde::Deserialize;
use serde_json::Value;
use tracing::{error, info};

use crate::{
    errors::ApiError,
    state::{AppState, FirebaseKeyCache},
};

#[derive(Debug, Deserialize)]
struct FirebaseClaims {
    sub: String,
}

#[derive(Clone)]
pub struct AuthContext {
    pub user_id: String,
}

pub async fn fetch_firebase_keys(http: &Client) -> Result<FirebaseKeyCache> {
    let resp = http
        .get("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com")
        .send()
        .await
        .context("failed to fetch Firebase public keys")?;

    let max_age_secs = resp
        .headers()
        .get("cache-control")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| {
            s.split(',').find_map(|part| {
                part.trim()
                    .strip_prefix("max-age=")
                    .and_then(|v| v.parse::<u64>().ok())
            })
        })
        .unwrap_or(3600);

    let jwk_set: Value = resp
        .error_for_status()
        .context("Firebase key endpoint returned error")?
        .json()
        .await
        .context("failed to parse Firebase JWK response")?;

    let mut keys = HashMap::new();
    if let Some(key_array) = jwk_set["keys"].as_array() {
        for jwk in key_array {
            let kid = match jwk["kid"].as_str() {
                Some(k) if !k.is_empty() => k.to_string(),
                _ => continue,
            };
            let n = jwk["n"].as_str().unwrap_or_default();
            let e = jwk["e"].as_str().unwrap_or_default();
            if n.is_empty() || e.is_empty() {
                continue;
            }
            match DecodingKey::from_rsa_components(n, e) {
                Ok(key) => {
                    keys.insert(kid, key);
                }
                Err(err) => {
                    error!("skipping invalid Firebase JWK key {kid}: {err}");
                }
            }
        }
    }
    if keys.is_empty() {
        return Err(anyhow!("Firebase JWK response contained no usable keys"));
    }

    info!("fetched {} Firebase public keys (cache {}s)", keys.len(), max_age_secs);
    Ok(FirebaseKeyCache {
        keys,
        expires_at: Instant::now() + std::time::Duration::from_secs(max_age_secs),
    })
}

pub async fn auth_middleware(
    State(state): State<Arc<AppState>>,
    mut request: Request,
    next: Next,
) -> Result<Response, ApiError> {
    let user_id = verify_authorization(&state, request.headers())
        .await
        .map_err(|e| ApiError::unauthorized(e.to_string()))?;
    request.extensions_mut().insert(AuthContext { user_id });
    Ok(next.run(request).await)
}

async fn verify_authorization(state: &AppState, headers: &HeaderMap) -> Result<String> {
    let value = headers
        .get(header::AUTHORIZATION)
        .ok_or_else(|| anyhow!("missing Authorization header"))?
        .to_str()
        .context("invalid Authorization header")?;
    let token = value
        .strip_prefix("Bearer ")
        .ok_or_else(|| anyhow!("expected Bearer token"))?;

    let jwt_header = decode_header(token).context("invalid JWT header")?;
    let kid = jwt_header.kid.ok_or_else(|| anyhow!("JWT missing kid claim"))?;

    let key = {
        let cache = state.firebase_keys.read().await;
        if Instant::now() < cache.expires_at {
            cache.keys.get(&kid).cloned()
        } else {
            None
        }
    };

    let key = match key {
        Some(k) => k,
        None => {
            let new_cache = fetch_firebase_keys(&state.http).await?;
            let k = new_cache
                .keys
                .get(&kid)
                .cloned()
                .ok_or_else(|| anyhow!("unknown JWT kid: {kid}"))?;
            *state.firebase_keys.write().await = new_cache;
            k
        }
    };

    let mut validation = Validation::new(Algorithm::RS256);
    validation.set_audience(&[state.firebase_project_id.as_str()]);
    validation.iss = Some(HashSet::from([format!(
        "https://securetoken.google.com/{}",
        state.firebase_project_id
    )]));

    let token_data = decode::<FirebaseClaims>(token, &key, &validation)
        .context("Firebase JWT verification failed")?;

    Ok(token_data.claims.sub)
}
