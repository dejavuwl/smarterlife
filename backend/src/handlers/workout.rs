use std::sync::Arc;

use axum::{extract::State, Extension, Json};
use serde_json::{json, Value};
use tracing::debug;

use crate::{
    auth::AuthContext,
    db::TxnErr,
    errors::ApiResult,
    logic::{current_date_string, now_timestamp},
    models::*,
    state::AppState,
};

pub async fn add_workout(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<AddWorkoutRequest>,
) -> ApiResult<Json<Value>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[addWorkout] incoming request"
    );
    let date = payload.date.unwrap_or_else(current_date_string);

    let intensity_multiplier = match payload.intensity.as_str() {
        "low" => 4.0,
        "medium" => 6.0,
        "high" => 8.0,
        _ => 5.0,
    };
    let burned = (payload.duration_minutes as f64 * intensity_multiplier).round();

    let workout_entry = json!({
        "type": payload.workout_type,
        "durationMinutes": payload.duration_minutes,
        "intensity": payload.intensity,
        "estimatedCaloriesBurned": burned,
        "loggedAt": now_timestamp(),
    });

    let user_id = auth.user_id.clone();
    let date_c = date.clone();
    let workout_entry_c = workout_entry.clone();

    let new_calories_burned: f64 = state
        .firestore
        .run_transaction(|db, txn| {
            let user_id = user_id.clone();
            let date = date_c.clone();
            let workout_entry = workout_entry_c.clone();
            Box::pin(async move {
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

                daily.workouts.push(workout_entry);
                daily.calories_burned += burned;

                let result = daily.calories_burned;

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

                Ok::<f64, backoff::Error<TxnErr>>(result)
            })
        })
        .await?;

    let resp = json!({
        "ok": true,
        "date": date,
        "caloriesBurned": new_calories_burned
    });
    debug!(user_id = %auth.user_id, response = ?resp.to_string(), "[addWorkout] response");
    Ok(Json(resp))
}
