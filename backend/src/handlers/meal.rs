use std::sync::Arc;

use anyhow::{anyhow, Context};
use axum::{extract::State, Extension, Json};
use serde_json::{json, Value};
use tracing::debug;

use crate::{
    auth::AuthContext,
    db::{FirestoreClient, TxnErr},
    errors::ApiResult,
    logic::{current_date_string, is_weight_or_volume, now_timestamp, upsert_catalog_item},
    models::*,
    openai::call_openai_json,
    state::AppState,
};

pub async fn add_meal(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<AddMealRequest>,
) -> ApiResult<Json<Value>> {
    debug!(
        user_id = %auth.user_id,
        request = ?serde_json::to_string(&payload).unwrap_or_default(),
        "[addMeal] incoming request"
    );
    let date = payload.date.unwrap_or_else(current_date_string);

    let total_calories = if is_weight_or_volume(&payload.unit) {
        payload.calories * payload.quantity / 100.0
    } else {
        payload.calories * payload.quantity
    };
    let meal_entry = json!({
        "name": payload.name,
        "caloriesPerUnit": payload.calories,
        "unit": payload.unit,
        "quantity": payload.quantity,
        "totalCalories": total_calories,
        "loggedAt": now_timestamp(),
    });

    // Clone all captures — run_transaction may retry the closure on contention.
    let user_id = auth.user_id.clone();
    let date_c = date.clone();
    let meal_entry_c = meal_entry.clone();
    let name_c = payload.name.clone();
    let cals_per_unit = payload.calories;
    let unit_c = payload.unit.clone();

    let new_calories_consumed: f64 = state
        .firestore
        .run_transaction(|db, txn| {
            let user_id = user_id.clone();
            let date = date_c.clone();
            let meal_entry = meal_entry_c.clone();
            let name = name_c.clone();
            let unit = unit_c.clone();
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

                let mut catalog: FoodCatalogDoc = db
                    .fluent()
                    .select()
                    .by_id_in("meta")
                    .parent(&parent)
                    .obj::<FoodCatalogDoc>()
                    .one("foodCatalog")
                    .await
                    .map_err(|e| backoff::Error::permanent(TxnErr(e.to_string())))?
                    .unwrap_or_default();

                daily.meals.push(meal_entry);
                daily.calories_consumed += total_calories;
                catalog.items = upsert_catalog_item(catalog.items, &name, cals_per_unit, &unit);

                let result = daily.calories_consumed;

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

                txn.update_object_at(
                    parent.as_ref(),
                    "meta",
                    "foodCatalog",
                    &catalog,
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
        "caloriesConsumed": new_calories_consumed
    });
    debug!(user_id = %auth.user_id, response = ?resp.to_string(), "[addMeal] response");
    Ok(Json(resp))
}

pub async fn parse_food(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<ParseFoodRequest>,
) -> ApiResult<Json<ParseFoodResponse>> {
    debug!(user_id = %auth.user_id, input = %payload.input, "[parseFood] incoming request");

    let firestore = FirestoreClient::new(&state.firestore);
    let catalog = firestore.get_food_catalog(&auth.user_id).await.unwrap_or_default();

    let catalog_hint = if catalog.is_empty() {
        String::new()
    } else {
        let entries: Vec<String> = catalog
            .iter()
            .take(30)
            .map(|e| format!("- {}: {}kcal/份", e.name, e.calories_per_unit))
            .collect();
        format!("\n用户历史食物参考（优先使用其中的热量数据）：\n{}", entries.join("\n"))
    };

    let system_prompt = format!(
        r#"你是专业营养分析助手。用户会描述吃了什么食物，请解析出每种食物，估算热量和数量。
{}
规则：
1. 将用户描述拆分为独立的食物条目
2. unit 选择最自然的计量单位：重量/体积类用 g 或 ml，固体食物默认用 g，液体用 ml；计件食物用 个/碗/杯/片/块等中文单位
3. caloriesPerUnit 的含义取决于 unit：
   - unit 为 g 或 ml 时：caloriesPerUnit = 每 100g 或每 100ml 的热量（kcal）
   - unit 为其他（个/碗/份/杯/片等）时：caloriesPerUnit = 每一个该单位的热量（kcal）
4. quantity 表示实际数量（克数、毫升数或件数）
5. 若用户历史有相同食物，优先使用历史热量数据

只返回 JSON，格式：
{{"items": [{{"name": "食物名", "caloriesPerUnit": 数字, "quantity": 数字, "unit": "单位"}}]}}"#,
        catalog_hint
    );

    let messages = vec![
        json!({"role": "system", "content": system_prompt}),
        json!({"role": "user", "content": payload.input}),
    ];

    let content = call_openai_json(&state, messages).await?;
    debug!(user_id = %auth.user_id, response = %content, "[parseFood] OpenAI response");

    let parsed: Value =
        serde_json::from_str(&content).context("failed to parse OpenAI JSON response")?;

    let items: Vec<ParsedFoodItem> = parsed["items"]
        .as_array()
        .ok_or_else(|| anyhow!("OpenAI response missing 'items' array"))?
        .iter()
        .filter_map(|item| {
            let name = item["name"].as_str()?.to_string();
            let calories_per_unit = item["caloriesPerUnit"].as_f64()?;
            let quantity = item["quantity"].as_f64().unwrap_or(1.0);
            let unit = item["unit"].as_str().unwrap_or("份").to_string();
            Some(ParsedFoodItem { name, calories_per_unit, quantity, unit })
        })
        .collect();

    Ok(Json(ParseFoodResponse { items }))
}

pub async fn get_food_catalog(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(_payload): Json<GetFoodCatalogRequest>,
) -> ApiResult<Json<FoodCatalogResponse>> {
    debug!(user_id = %auth.user_id, "[getFoodCatalog] incoming request");
    let firestore = FirestoreClient::new(&state.firestore);
    let mut items = firestore.get_food_catalog(&auth.user_id).await.unwrap_or_default();
    items.sort_by(|a, b| b.times_used.cmp(&a.times_used));
    Ok(Json(FoodCatalogResponse { items }))
}

pub async fn refine_calories(
    State(state): State<Arc<AppState>>,
    Extension(auth): Extension<AuthContext>,
    Json(payload): Json<RefineCaloriesRequest>,
) -> ApiResult<Json<RefineCaloriesResponse>> {
    debug!(
        user_id = %auth.user_id,
        name = %payload.name,
        unit = %payload.unit,
        "[refineCalories] incoming request"
    );

    let per_unit_label = if is_weight_or_volume(&payload.unit) {
        format!("每100{}", payload.unit)
    } else {
        format!("每{}", payload.unit)
    };

    let prompt = format!(
        r#"你是专业营养师。请根据以下信息精确估算食物热量。

食物：{name}
当前估算：{current:.0} kcal（{per_unit}）
用户补充说明：{context}

请综合食物名称和用户说明，给出更准确的热量估算。
只返回 JSON：{{"caloriesPerUnit": 数字, "explanation": "一句话说明估算依据"}}"#,
        name = payload.name,
        current = payload.current_estimate,
        per_unit = per_unit_label,
        context = payload.context,
    );

    let messages = vec![json!({"role": "user", "content": prompt})];
    let content = call_openai_json(&state, messages).await?;
    debug!(user_id = %auth.user_id, response = %content, "[refineCalories] OpenAI response");

    let parsed: Value =
        serde_json::from_str(&content).context("failed to parse refine response")?;

    let calories_per_unit =
        parsed["caloriesPerUnit"].as_f64().unwrap_or(payload.current_estimate);
    let explanation = parsed["explanation"].as_str().unwrap_or("").to_string();

    Ok(Json(RefineCaloriesResponse { calories_per_unit, explanation }))
}
