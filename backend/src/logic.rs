use anyhow::{Context, Result};
use chrono::{Datelike, NaiveDate, Utc};
use serde_json::{json, Value};

use crate::models::*;

pub const MAX_HEALTHY_DAILY_DEFICIT: f64 = 900.0;

// ── Utilities ─────────────────────────────────────────────────────────────────

pub fn current_date_string() -> String {
    let now = Utc::now().date_naive();
    format!("{:04}-{:02}-{:02}", now.year(), now.month(), now.day())
}

pub fn now_timestamp() -> String {
    Utc::now().to_rfc3339()
}

pub fn round1(value: f64) -> f64 {
    (value * 10.0).round() / 10.0
}

pub fn is_weight_or_volume(unit: &str) -> bool {
    matches!(
        unit.to_lowercase().as_str(),
        "g" | "ml" | "克" | "毫升" | "kg" | "l" | "千克" | "升"
    )
}

// ── Summary & plan logic ──────────────────────────────────────────────────────

pub fn compute_summary(profile: Profile, daily: Option<DailyStats>, today: &str) -> ComputedSummary {
    let age = profile.age.unwrap_or(30) as f64;
    let current_weight = profile.current_weight_kg;
    let bmr = match profile.gender.as_deref() {
        Some("male") => 10.0 * current_weight + 6.25 * profile.height_cm - 5.0 * age + 5.0,
        Some("female") => 10.0 * current_weight + 6.25 * profile.height_cm - 5.0 * age - 161.0,
        _ => 10.0 * current_weight + 6.25 * profile.height_cm - 5.0 * age - 78.0,
    };
    let tdee = bmr * 1.4;

    let total_loss_needed = (profile.start_weight_kg - profile.target_weight_kg).max(0.0);
    let remaining_loss = (current_weight - profile.target_weight_kg).max(0.0);
    let total_deficit_needed = remaining_loss * 7700.0;
    let days_left = {
        let plan_end = NaiveDate::parse_from_str(&profile.plan_start_date, "%Y-%m-%d")
            .ok()
            .and_then(|s| s.checked_add_days(chrono::Days::new(profile.target_days.max(0) as u64)));
        let today_date = NaiveDate::parse_from_str(today, "%Y-%m-%d").ok();
        match (plan_end, today_date) {
            (Some(end), Some(td)) => (end - td).num_days().max(1) as f64,
            _ => profile.target_days.max(1) as f64,
        }
    };
    let recommended_deficit = if profile.plan_paused || current_weight <= profile.target_weight_kg {
        0.0
    } else {
        (total_deficit_needed / days_left).clamp(0.0, MAX_HEALTHY_DAILY_DEFICIT)
    };
    let recommended_calorie_target =
        if profile.plan_paused || current_weight <= profile.target_weight_kg {
            tdee
        } else {
            (tdee - recommended_deficit).max(1200.0)
        };

    let daily = daily.unwrap_or_default();
    let remaining_calories =
        recommended_calorie_target - daily.calories_consumed + daily.calories_burned;
    let progress_percent = if total_loss_needed <= 0.0 {
        1.0
    } else {
        ((profile.start_weight_kg - current_weight) / total_loss_needed).clamp(0.0, 1.0)
    };

    ComputedSummary {
        bmr: round1(bmr),
        tdee: round1(tdee),
        recommended_deficit: round1(recommended_deficit),
        recommended_calorie_target: round1(recommended_calorie_target),
        current_weight_kg: round1(current_weight),
        target_weight_kg: round1(profile.target_weight_kg),
        calories_consumed: round1(daily.calories_consumed),
        calories_burned: round1(daily.calories_burned),
        remaining_calories: round1(remaining_calories),
        progress_percent: (progress_percent * 1000.0).round() / 10.0,
    }
}

pub fn current_target_date(profile: &Profile) -> String {
    NaiveDate::parse_from_str(&profile.plan_start_date, "%Y-%m-%d")
        .ok()
        .and_then(|start| {
            start.checked_add_days(chrono::Days::new(profile.target_days.max(0) as u64))
        })
        .map(|d| d.format("%Y-%m-%d").to_string())
        .unwrap_or_else(|| profile.plan_start_date.clone())
}

pub fn raw_required_deficit(profile: &Profile, today: &str) -> f64 {
    if profile.plan_paused || profile.current_weight_kg <= profile.target_weight_kg {
        return 0.0;
    }
    let remaining_loss = (profile.current_weight_kg - profile.target_weight_kg).max(0.0);
    let total_deficit_needed = remaining_loss * 7700.0;
    let days_left = {
        let plan_end = NaiveDate::parse_from_str(&profile.plan_start_date, "%Y-%m-%d")
            .ok()
            .and_then(|s| s.checked_add_days(chrono::Days::new(profile.target_days.max(0) as u64)));
        let today_date = NaiveDate::parse_from_str(today, "%Y-%m-%d").ok();
        match (plan_end, today_date) {
            (Some(end), Some(td)) => (end - td).num_days().max(1) as f64,
            _ => profile.target_days.max(1) as f64,
        }
    };
    total_deficit_needed / days_left
}

pub fn evaluate_plan_state(profile: &Profile, today: &str) -> PlanEvaluation {
    let raw_deficit = raw_required_deficit(profile, today);
    let target_date = current_target_date(profile);
    if profile.current_weight_kg <= profile.target_weight_kg {
        PlanEvaluation {
            action_type: Some("completed_or_record_only"),
            message: "当前体重已经达到或超过原计划目标。请开启新计划，或先切换为仅记录模式。"
                .to_string(),
            raw_required_deficit: 0.0,
            max_healthy_deficit: MAX_HEALTHY_DAILY_DEFICIT,
            current_target_date: target_date,
        }
    } else if !profile.plan_paused && raw_deficit > MAX_HEALTHY_DAILY_DEFICIT {
        PlanEvaluation {
            action_type: Some("update_or_pause"),
            message: format!(
                "按当前计划剩余时间计算，日均热量赤字约为 {:.0} kcal，已超过健康上限 {:.0} kcal。建议先更新目标日期或目标体重，或暂停计划只做记录。",
                raw_deficit, MAX_HEALTHY_DAILY_DEFICIT
            ),
            raw_required_deficit: raw_deficit,
            max_healthy_deficit: MAX_HEALTHY_DAILY_DEFICIT,
            current_target_date: target_date,
        }
    } else if profile.plan_paused {
        PlanEvaluation {
            action_type: Some("paused"),
            message: "当前计划已暂停，将以健康维持为目标给出建议。".to_string(),
            raw_required_deficit: 0.0,
            max_healthy_deficit: MAX_HEALTHY_DAILY_DEFICIT,
            current_target_date: target_date,
        }
    } else {
        PlanEvaluation {
            action_type: None,
            message: String::new(),
            raw_required_deficit: raw_deficit,
            max_healthy_deficit: MAX_HEALTHY_DAILY_DEFICIT,
            current_target_date: target_date,
        }
    }
}

pub fn plan_evaluation_json(plan: &PlanEvaluation, profile: &Profile) -> Value {
    json!({
        "actionRequired": plan.action_type.is_some() && plan.action_type != Some("paused"),
        "actionType": plan.action_type,
        "message": plan.message,
        "rawRequiredDeficit": round1(plan.raw_required_deficit),
        "maxHealthyDeficit": plan.max_healthy_deficit,
        "currentTargetWeightKg": round1(profile.target_weight_kg),
        "currentTargetDate": plan.current_target_date,
        "planPaused": profile.plan_paused,
    })
}

pub fn compute_recommendation(
    profile: Profile,
    daily: DailyStats,
    today: &str,
) -> Result<RecommendationResponse> {
    let base_summary = compute_summary(profile.clone(), Some(daily.clone()), today);
    let start_date = NaiveDate::parse_from_str(&profile.plan_start_date, "%Y-%m-%d")
        .context("invalid planStartDate")?;
    let today_date = NaiveDate::parse_from_str(today, "%Y-%m-%d").context("invalid date")?;
    let elapsed_days = (today_date - start_date).num_days().max(0) as f64;
    let total_loss_needed = (profile.start_weight_kg - profile.target_weight_kg).max(0.0);
    let planned_loss = if profile.target_days <= 0 {
        0.0
    } else {
        total_loss_needed * (elapsed_days / profile.target_days as f64).clamp(0.0, 1.0)
    };
    let actual_loss = (profile.start_weight_kg - profile.current_weight_kg).max(0.0);
    let lag = planned_loss - actual_loss;

    let (status, calorie_target, message) = if profile.current_weight_kg <= profile.target_weight_kg
    {
        (
            "balanced",
            round1(base_summary.tdee),
            "Goal reached. Switch to maintenance calories and keep your training rhythm."
                .to_string(),
        )
    } else if lag > 0.4 {
        let tightened_target = (base_summary.recommended_calorie_target - 150.0).max(1200.0);
        (
            "overweight_adjusted",
            round1(tightened_target),
            format!(
                "Weight loss is behind plan by about {:.1} kg. Aim for {:.0} kcal today or add 20-30 minutes of moderate exercise.",
                lag, tightened_target
            ),
        )
    } else if base_summary.remaining_calories < 0.0 {
        (
            "deficit",
            base_summary.recommended_calorie_target,
            format!(
                "You are about {:.0} kcal over the daily budget. Keep dinner high-protein and add 15-20 minutes of light to moderate activity.",
                base_summary.remaining_calories.abs()
            ),
        )
    } else {
        (
            "balanced",
            base_summary.recommended_calorie_target,
            format!(
                "Progress is on track. You still have about {:.0} kcal remaining today. Favor high-protein and high-fiber food choices.",
                base_summary.remaining_calories.max(0.0)
            ),
        )
    };

    Ok(RecommendationResponse {
        status: status.to_string(),
        recommended_calorie_target: calorie_target,
        suggested_message: message,
    })
}

// ── Catalog helper ────────────────────────────────────────────────────────────

pub fn upsert_catalog_item(
    mut items: Vec<FoodCatalogItem>,
    food_name: &str,
    calories_per_unit: f64,
    unit: &str,
) -> Vec<FoodCatalogItem> {
    let name_lower = food_name.trim().to_lowercase();
    if let Some(entry) = items.iter_mut().find(|e| e.name.to_lowercase() == name_lower) {
        entry.calories_per_unit = calories_per_unit;
        entry.unit = unit.to_string();
        entry.times_used += 1;
    } else {
        items.push(FoodCatalogItem {
            name: food_name.trim().to_string(),
            calories_per_unit,
            unit: unit.to_string(),
            times_used: 1,
        });
    }
    items.sort_by(|a, b| b.times_used.cmp(&a.times_used));
    items.truncate(200);
    items
}
