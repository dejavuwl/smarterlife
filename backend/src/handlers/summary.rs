use std::sync::Arc;

use axum::{extract::State, Extension, Json};
use tracing::debug;

use crate::{
    auth::AuthContext,
    db::FirestoreClient,
    errors::ApiResult,
    logic::{compute_recommendation, compute_summary, current_date_string},
    models::*,
    state::AppState,
};

pub async fn daily_summary(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<DailySummaryRequest>,
) -> ApiResult<Json<DailySummaryResponse>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[dailySummary] incoming request"
    );
    let firestore = FirestoreClient::new(&state.firestore);
    let date = payload.date.unwrap_or_else(current_date_string);

    let (profile, daily) = tokio::try_join!(
        firestore.get_profile(&auth.user_id),
        firestore.get_daily_stats(&auth.user_id, &date),
    )?;

    let summary = compute_summary(profile, Some(daily), &date);

    let resp = DailySummaryResponse {
        date,
        current_weight_kg: summary.current_weight_kg,
        target_weight_kg: summary.target_weight_kg,
        calorie_target: summary.recommended_calorie_target,
        deficit_target: summary.recommended_deficit,
        calories_consumed: summary.calories_consumed,
        calories_burned: summary.calories_burned,
        remaining_calories: summary.remaining_calories,
        progress_percent: summary.progress_percent,
        bmr: summary.bmr,
        tdee: summary.tdee,
    };
    debug!(
        user_id = %auth.user_id,
        response = ?serde_json::to_string(&resp).unwrap_or_default(),
        "[dailySummary] response"
    );
    Ok(Json(resp))
}

pub async fn recommendation(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<RecommendationRequest>,
) -> ApiResult<Json<RecommendationResponse>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[recommendation] incoming request"
    );
    let firestore = FirestoreClient::new(&state.firestore);
    let date = payload.date.unwrap_or_else(current_date_string);

    let (profile, daily) = tokio::try_join!(
        firestore.get_profile(&auth.user_id),
        firestore.get_daily_stats(&auth.user_id, &date),
    )?;

    let rec = compute_recommendation(profile, daily, &date)?;
    debug!(
        user_id = %auth.user_id,
        response = ?serde_json::to_string(&rec).unwrap_or_default(),
        "[recommendation] response"
    );
    Ok(Json(rec))
}

pub async fn get_daily_records(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<GetDailyRecordsRequest>,
) -> ApiResult<Json<GetDailyRecordsResponse>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[getDailyRecords] incoming request"
    );
    let firestore = FirestoreClient::new(&state.firestore);
    let date = payload.date.unwrap_or_else(current_date_string);
    let daily = firestore.get_daily_stats(&auth.user_id, &date).await?;
    let resp = GetDailyRecordsResponse { date, meals: daily.meals, workouts: daily.workouts };
    debug!(
        user_id = %auth.user_id,
        response = ?serde_json::to_string(&resp).unwrap_or_default(),
        "[getDailyRecords] response"
    );
    Ok(Json(resp))
}
