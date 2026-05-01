use std::sync::Arc;

use axum::{extract::State, Extension, Json};
use chrono::NaiveDate;
use serde_json::{json, Value};
use tracing::debug;

use crate::{
    auth::AuthContext,
    db::{FirestoreClient, TxnErr},
    errors::{ApiError, ApiResult},
    logic::{compute_summary, current_date_string, evaluate_plan_state, plan_evaluation_json},
    models::*,
    state::AppState,
};

pub async fn setup_user(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<SetupUserRequest>,
) -> ApiResult<Json<Value>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[setupUser] incoming request"
    );
    let firestore = FirestoreClient::new(&state.firestore);
    let today = current_date_string();

    let profile = Profile {
        height_cm: payload.height_cm,
        current_weight_kg: payload.weight_kg,
        start_weight_kg: payload.weight_kg,
        target_weight_kg: payload.target_weight_kg,
        target_days: payload.target_days,
        gender: payload.gender.clone(),
        age: payload.age,
        plan_start_date: today.clone(),
        plan_paused: false,
    };

    tokio::try_join!(
        firestore.set_profile(&auth.user_id, &profile),
        firestore.create_weight_history(&auth.user_id, payload.weight_kg, "setup"),
    )?;

    let summary = compute_summary(profile, None, &today);

    let resp = json!({ "ok": true, "summary": summary });
    debug!(user_id = %auth.user_id, response = ?resp.to_string(), "[setupUser] response");
    Ok(Json(resp))
}

pub async fn update_weight(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<UpdateWeightRequest>,
) -> ApiResult<Json<Value>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[updateWeight] incoming request"
    );
    let date = payload.date.unwrap_or_else(current_date_string);
    let weight_kg = payload.weight_kg;

    let user_id = auth.user_id.clone();
    let date_c = date.clone();

    // Transaction atomically reads profile, updates current weight, and stamps daily stats.
    let updated_profile: Option<Profile> = state
        .firestore
        .run_transaction(|db, txn| {
            let user_id = user_id.clone();
            let date = date_c.clone();
            Box::pin(async move {
                let maybe: Option<Profile> = db
                    .fluent()
                    .select()
                    .by_id_in("users")
                    .obj::<Profile>()
                    .one(&user_id)
                    .await
                    .map_err(|e| backoff::Error::permanent(TxnErr(e.to_string())))?;

                let profile = match maybe {
                    Some(p) => p,
                    None => return Ok::<Option<Profile>, backoff::Error<TxnErr>>(None),
                };

                let parent = db
                    .parent_path("users", &user_id)
                    .map_err(|e| backoff::Error::permanent(TxnErr(e.to_string())))?;

                let mut daily: DailyStats = db
                    .fluent()
                    .select()
                    .by_id_in("dailyStats")
                    .parent(&parent)
                    .obj::<DailyStats>()
                    .one(&date)
                    .await
                    .map_err(|e| backoff::Error::permanent(TxnErr(e.to_string())))?
                    .unwrap_or_default();

                let updated = Profile { current_weight_kg: weight_kg, ..profile };
                daily.latest_weight_kg = Some(weight_kg);

                txn.update_object("users", &user_id, &updated, None, None, vec![])
                    .map_err(|e| backoff::Error::permanent(TxnErr(e.to_string())))?;

                txn.update_object_at(
                    parent.as_ref(),
                    "dailyStats",
                    &date,
                    &daily,
                    None,
                    None,
                    vec![],
                )
                .map_err(|e| backoff::Error::permanent(TxnErr(e.to_string())))?;

                Ok::<Option<Profile>, backoff::Error<TxnErr>>(Some(updated))
            })
        })
        .await?;

    let updated_profile =
        updated_profile.ok_or_else(|| ApiError::bad_request("user profile not found"))?;

    // Weight history is append-only — safe to insert outside the transaction.
    let firestore = FirestoreClient::new(&state.firestore);
    firestore.create_weight_history(&auth.user_id, weight_kg, "manual_update").await?;

    let resp = json!({
        "ok": true,
        "planEvaluation": plan_evaluation_json(&evaluate_plan_state(&updated_profile, &date), &updated_profile),
    });
    debug!(user_id = %auth.user_id, response = ?resp.to_string(), "[updateWeight] response");
    Ok(Json(resp))
}

pub async fn update_plan(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<UpdatePlanRequest>,
) -> ApiResult<Json<Value>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[updatePlan] incoming request"
    );
    let firestore = FirestoreClient::new(&state.firestore);
    let profile = firestore.get_profile(&auth.user_id).await?;
    let today = current_date_string();

    let paused = payload.paused.unwrap_or(false);
    let target_weight_kg = payload.target_weight_kg.unwrap_or(profile.target_weight_kg);
    let target_days = if paused {
        profile.target_days
    } else {
        let target_date = payload.target_date.as_deref().ok_or_else(|| {
            ApiError::bad_request("target_date is required when updating an active plan")
        })?;
        let target = NaiveDate::parse_from_str(target_date, "%Y-%m-%d")
            .map_err(|_| ApiError::bad_request("target_date must be YYYY-MM-DD"))?;
        let start = NaiveDate::parse_from_str(&today, "%Y-%m-%d")
            .map_err(|_| ApiError::bad_request("failed to parse current date"))?;
        (target - start).num_days().max(1)
    };

    let updated_profile = Profile {
        start_weight_kg: if paused { profile.start_weight_kg } else { profile.current_weight_kg },
        target_weight_kg,
        target_days,
        plan_start_date: if paused { profile.plan_start_date.clone() } else { today.clone() },
        plan_paused: paused,
        ..profile
    };

    firestore.set_profile(&auth.user_id, &updated_profile).await?;

    let resp = json!({
        "ok": true,
        "planEvaluation": plan_evaluation_json(&evaluate_plan_state(&updated_profile, &today), &updated_profile),
    });
    debug!(user_id = %auth.user_id, response = ?resp.to_string(), "[updatePlan] response");
    Ok(Json(resp))
}
