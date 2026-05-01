use std::sync::Arc;

use anyhow::Context;
use axum::{extract::State, http::StatusCode, Extension, Json};
use chrono::{NaiveDate, Utc};
use serde_json::{json, Value};
use tracing::{debug, error};

use crate::{
    auth::AuthContext,
    db::FirestoreClient,
    errors::{ApiError, ApiResult},
    logic::{
        compute_summary, current_date_string, evaluate_plan_state, plan_evaluation_json, round1,
    },
    models::*,
    openai::call_openai_json,
    state::AppState,
};

pub async fn llm_recommendation(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<LlmRecommendationRequest>,
) -> ApiResult<Json<Value>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[llmRecommendation] incoming request"
    );
    let firestore = FirestoreClient::new(&state.firestore);
    let date = payload.date.unwrap_or_else(current_date_string);

    let (profile, daily) = tokio::try_join!(
        firestore.get_profile(&auth.user_id),
        firestore.get_daily_stats(&auth.user_id, &date),
    )?;

    let summary = compute_summary(profile.clone(), Some(daily.clone()), &date);
    let plan = evaluate_plan_state(&profile, &date);
    if matches!(
        plan.action_type,
        Some("update_or_pause") | Some("completed_or_record_only")
    ) {
        return Ok(Json(json!({
            "kind": "plan_action_required",
            "planEvaluation": plan_evaluation_json(&plan, &profile),
        })));
    }

    let age = profile.age.unwrap_or(30);
    let gender_label = match profile.gender.as_deref() {
        Some("male") => "男",
        Some("female") => "女",
        _ => "未知",
    };

    let meals_str = if daily.meals.is_empty() {
        "（今日暂无记录）".to_string()
    } else {
        daily
            .meals
            .iter()
            .map(|m| {
                let name = m["name"].as_str().unwrap_or("未知");
                let total = m["totalCalories"].as_f64().unwrap_or(0.0);
                format!("- {} ({:.0}kcal)", name, total)
            })
            .collect::<Vec<_>>()
            .join("\n")
    };

    let workouts_str = if daily.workouts.is_empty() {
        "（今日暂无记录）".to_string()
    } else {
        daily
            .workouts
            .iter()
            .map(|w| {
                let wtype = w["type"].as_str().unwrap_or("未知");
                let duration = w["durationMinutes"].as_i64().unwrap_or(0);
                let burned = w["estimatedCaloriesBurned"].as_f64().unwrap_or(0.0);
                format!("- {} {}分钟（消耗约{:.0}kcal）", wtype, duration, burned)
            })
            .collect::<Vec<_>>()
            .join("\n")
    };

    let preferences_str = payload
        .preferences
        .as_deref()
        .filter(|s| !s.trim().is_empty())
        .map(|s| format!("\n用户偏好/备注：{}", s))
        .unwrap_or_default();

    let system_prompt = format!(
        r#"你是专业营养师和健身教练。根据用户今日饮食和运动记录，给出个性化的一日三餐建议和运动计划。

用户信息：{gender_label}性，{age}岁，当前体重{weight:.1}kg，目标体重{target:.1}kg
今日热量目标：{calorie_target:.0}kcal（热量赤字目标：{deficit:.0}kcal）
已摄入：{consumed:.0}kcal，已消耗（运动）：{burned:.0}kcal，剩余可用：{remaining:.0}kcal
计划状态：{plan_msg}{preferences}

今日饮食记录：
{meals}

今日运动记录：
{workouts}

请给出：
1. 今日剩余餐食建议（根据剩余热量）
2. 明日一日三餐建议（具体食物和大致热量）
3. 运动建议（类型、时长、消耗）
4. 一句话总结今日表现和明日重点

只返回 JSON，格式：
{{
  "status": "on_track|behind|ahead",
  "recommendedCalorieTarget": 数字,
  "remainingCalories": 数字,
  "summaryMessage": "一句话总结",
  "meals": [
    {{
      "mealType": "breakfast|lunch|dinner|snack",
      "mealTypeLabel": "早餐|午餐|晚餐|加餐",
      "totalCalories": 数字,
      "items": [{{"name": "食物名", "calories": 数字, "quantity": 数字, "unit": "单位"}}]
    }}
  ],
  "exercises": [{{"name": "运动名", "durationMinutes": 数字, "estimatedCaloriesBurned": 数字}}]
}}"#,
        gender_label = gender_label,
        age = age,
        weight = profile.current_weight_kg,
        target = profile.target_weight_kg,
        calorie_target = summary.recommended_calorie_target,
        deficit = summary.recommended_deficit,
        consumed = summary.calories_consumed,
        burned = summary.calories_burned,
        remaining = summary.remaining_calories,
        plan_msg = plan.message,
        preferences = preferences_str,
        meals = meals_str,
        workouts = workouts_str,
    );

    let messages = vec![json!({"role": "user", "content": system_prompt})];
    let content = call_openai_json(&state, messages).await?;
    debug!(user_id = %auth.user_id, response = %content, "[llmRecommendation] OpenAI response");

    let resp: LlmRecommendationResponse =
        serde_json::from_str(&content).context("failed to parse LLM recommendation response")?;
    debug!(user_id = %auth.user_id, status = %resp.status, "[llmRecommendation] response");

    // Persist recommendation snapshot (best-effort)
    let days_elapsed = {
        let plan_start = NaiveDate::parse_from_str(&profile.plan_start_date, "%Y-%m-%d").ok();
        let today_date = NaiveDate::parse_from_str(&date, "%Y-%m-%d").ok();
        match (plan_start, today_date) {
            (Some(start), Some(td)) => (td - start).num_days().max(0),
            _ => 0,
        }
    };
    let days_remaining = {
        let plan_end = NaiveDate::parse_from_str(&profile.plan_start_date, "%Y-%m-%d")
            .ok()
            .and_then(|s| s.checked_add_days(chrono::Days::new(profile.target_days.max(0) as u64)));
        let today_date = NaiveDate::parse_from_str(&date, "%Y-%m-%d").ok();
        match (plan_end, today_date) {
            (Some(end), Some(td)) => (end - td).num_days().max(0),
            _ => profile.target_days.max(0),
        }
    };
    let rec_doc = json!({
        "date": date,
        "savedAt": Utc::now().to_rfc3339(),
        "status": resp.status,
        "summaryMessage": resp.summary_message,
        "recommendedCalorieTarget": resp.recommended_calorie_target,
        "remainingCalories": resp.remaining_calories,
        "bodySnapshot": {
            "heightCm": profile.height_cm,
            "weightKg": profile.current_weight_kg,
            "targetWeightKg": profile.target_weight_kg,
            "gender": profile.gender,
            "age": profile.age,
        },
        "planSnapshot": {
            "caloriesConsumed": summary.calories_consumed,
            "caloriesBurned": summary.calories_burned,
            "remainingCalories": summary.remaining_calories,
            "deficitTarget": summary.recommended_deficit,
            "calorieTarget": summary.recommended_calorie_target,
            "bmr": summary.bmr,
            "tdee": summary.tdee,
            "progressPercent": summary.progress_percent,
            "daysElapsed": days_elapsed,
            "daysRemaining": days_remaining,
        },
        "meals": resp.meals,
        "exercises": resp.exercises,
    });
    if let Err(e) = firestore.save_ai_recommendation(&auth.user_id, &date, rec_doc).await {
        error!("failed to save ai recommendation: {e:#}");
    }

    Ok(Json(json!({
        "kind": "recommendation",
        "status": resp.status,
        "recommendedCalorieTarget": resp.recommended_calorie_target,
        "remainingCalories": resp.remaining_calories,
        "summaryMessage": resp.summary_message,
        "meals": resp.meals,
        "exercises": resp.exercises,
    })))
}

pub async fn plan_adjustment_suggestion(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<PlanAdjustmentSuggestionRequest>,
) -> ApiResult<Json<PlanAdjustmentSuggestionResponse>> {
    let firestore = FirestoreClient::new(&state.firestore);
    let date = payload.date.unwrap_or_else(current_date_string);
    let profile = firestore.get_profile(&auth.user_id).await?;
    let plan = evaluate_plan_state(&profile, &date);
    if profile.current_weight_kg <= profile.target_weight_kg {
        return Err(ApiError::bad_request("plan already completed"));
    }

    let system_prompt = r#"你是专业营养师。用户当前减重计划过于激进，请在健康前提下给出更现实的新目标。
只返回 JSON：
{"targetWeightKg": 数字, "targetDate": "YYYY-MM-DD", "reason": "中文一句话说明"}"#;
    let user_prompt = format!(
        "用户当前体重 {:.1}kg，当前目标体重 {:.1}kg，当前目标完成日期 {}。按现计划需要每日热量赤字 {:.0}kcal，健康上限为 {:.0}kcal。请给出更现实的新目标体重和目标日期，优先保留减重方向，但不要给出不健康方案。",
        profile.current_weight_kg,
        profile.target_weight_kg,
        plan.current_target_date,
        plan.raw_required_deficit,
        plan.max_healthy_deficit
    );

    let content = call_openai_json(
        &state,
        vec![
            json!({"role": "system", "content": system_prompt}),
            json!({"role": "user", "content": user_prompt}),
        ],
    )
    .await?;
    let parsed: Value =
        serde_json::from_str(&content).context("failed to parse plan adjustment suggestion")?;

    let target_weight_kg = parsed["targetWeightKg"]
        .as_f64()
        .unwrap_or(profile.target_weight_kg)
        .min(profile.current_weight_kg)
        .max(profile.target_weight_kg);
    let target_date = parsed["targetDate"]
        .as_str()
        .unwrap_or(&plan.current_target_date)
        .to_string();
    let reason = parsed["reason"]
        .as_str()
        .unwrap_or("建议延长周期或分阶段减重，以确保计划更可持续。")
        .to_string();

    Ok(Json(PlanAdjustmentSuggestionResponse {
        target_weight_kg: round1(target_weight_kg),
        target_date,
        reason,
    }))
}

pub async fn get_ai_recommendation_history(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<GetAiRecommendationHistoryRequest>,
) -> ApiResult<Json<GetAiRecommendationHistoryResponse>> {
    let firestore = FirestoreClient::new(&state.firestore);
    let limit = payload.limit.unwrap_or(30).clamp(1, 100);
    let items = firestore.list_ai_recommendations(&auth.user_id, limit).await?;
    Ok(Json(GetAiRecommendationHistoryResponse { items }))
}

pub async fn get_ai_recommendation_detail(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<GetAiRecommendationDetailRequest>,
) -> ApiResult<Json<AiRecommendationDetail>> {
    let firestore = FirestoreClient::new(&state.firestore);
    let detail = firestore
        .get_ai_recommendation_by_date(&auth.user_id, &payload.date)
        .await?
        .ok_or_else(|| ApiError {
            status: StatusCode::NOT_FOUND,
            message: format!("no recommendation found for date {}", payload.date),
        })?;
    Ok(Json(detail))
}
