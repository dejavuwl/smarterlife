use std::{env, net::SocketAddr, sync::Arc};

use anyhow::Context;
use axum::{
    http::{header, Method},
    middleware,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use firestore::FirestoreDb;
use reqwest::Client;
use serde_json::json;
use tokio::sync::RwLock;
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use tracing::info;

mod auth;
mod db;
mod errors;
mod handlers;
mod logic;
mod models;
mod openai;
mod state;

use auth::{auth_middleware, fetch_firebase_keys};
use handlers::{
    ai::{
        get_ai_recommendation_detail, get_ai_recommendation_history, llm_recommendation,
        plan_adjustment_suggestion,
    },
    meal::{add_meal, get_food_catalog, parse_food, refine_calories},
    summary::{daily_summary, get_daily_records, recommendation},
    user::{setup_user, update_plan, update_weight},
    workout::add_workout,
};
use state::AppState;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            env::var("RUST_LOG").unwrap_or_else(|_| "smarterlife_api=info,tower_http=info".into()),
        )
        .init();

    let project_id = env::var("GCP_PROJECT")
        .or_else(|_| env::var("GOOGLE_CLOUD_PROJECT"))
        .context("GCP_PROJECT or GOOGLE_CLOUD_PROJECT is required")?;
    let openai_api_key = env::var("OPENAI_API_KEY")
        .context("OPENAI_API_KEY is required for AI food parsing and recommendations")?;
    let openai_base_url =
        env::var("OPENAI_BASE_URL").unwrap_or_else(|_| "https://api.openai.com".to_string());

    let http = Client::new();
    let firebase_keys = fetch_firebase_keys(&http)
        .await
        .context("failed to fetch Firebase public keys on startup")?;

    let firestore_db = FirestoreDb::new(&project_id)
        .await
        .context("failed to initialize Firestore gRPC client")?;

    let state = Arc::new(AppState {
        http,
        firestore: firestore_db,
        firebase_project_id: project_id,
        firebase_keys: Arc::new(RwLock::new(firebase_keys)),
        openai_api_key,
        openai_base_url,
    });

    let app = Router::new()
        .route("/health", get(health))
        .route("/setupUser", post(setup_user))
        .route("/addMeal", post(add_meal))
        .route("/addWorkout", post(add_workout))
        .route("/updateWeight", post(update_weight))
        .route("/updatePlan", post(update_plan))
        .route("/planAdjustmentSuggestion", post(plan_adjustment_suggestion))
        .route("/dailySummary", post(daily_summary))
        .route("/recommendation", post(recommendation))
        .route("/parseFood", post(parse_food))
        .route("/getFoodCatalog", post(get_food_catalog))
        .route("/llmRecommendation", post(llm_recommendation))
        .route("/getAiRecommendationHistory", post(get_ai_recommendation_history))
        .route("/getAiRecommendationDetail", post(get_ai_recommendation_detail))
        .route("/refineCalories", post(refine_calories))
        .route("/getDailyRecords", post(get_daily_records))
        .layer(
            CorsLayer::new()
                .allow_methods([Method::GET, Method::POST, Method::OPTIONS])
                .allow_headers([header::AUTHORIZATION, header::CONTENT_TYPE])
                .allow_origin(tower_http::cors::Any),
        )
        .layer(TraceLayer::new_for_http())
        .route_layer(middleware::from_fn_with_state(state.clone(), auth_middleware))
        .with_state(state);

    let port = env::var("PORT")
        .ok()
        .and_then(|s| s.parse::<u16>().ok())
        .unwrap_or(8080);
    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    info!("listening on {}", addr);
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;
    Ok(())
}

async fn health() -> impl IntoResponse {
    Json(json!({ "ok": true }))
}
