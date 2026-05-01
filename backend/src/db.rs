use anyhow::{anyhow, Context, Result};
use firestore::{FirestoreDb, FirestoreQueryDirection};
use futures::stream::TryStreamExt;
use serde_json::Value;

use crate::{logic::now_timestamp, models::*};

/// Minimal error type satisfying run_transaction's E: StdError + Send + Sync + 'static bound.
#[derive(Debug)]
pub struct TxnErr(pub String);

impl std::fmt::Display for TxnErr {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

impl std::error::Error for TxnErr {}

pub struct FirestoreClient<'a> {
    pub db: &'a FirestoreDb,
}

impl<'a> FirestoreClient<'a> {
    pub fn new(db: &'a FirestoreDb) -> Self {
        Self { db }
    }

    // ── Profile ───────────────────────────────────────────────────────────────

    pub async fn get_profile(&self, user_id: &str) -> Result<Profile> {
        self.db
            .fluent()
            .select()
            .by_id_in("users")
            .obj::<Profile>()
            .one(user_id)
            .await
            .context("get_profile")?
            .ok_or_else(|| anyhow!("profile not found"))
    }

    pub async fn set_profile(&self, user_id: &str, profile: &Profile) -> Result<()> {
        self.db
            .fluent()
            .update()
            .in_col("users")
            .document_id(user_id)
            .object(profile)
            .execute::<Profile>()
            .await
            .context("set_profile")?;
        Ok(())
    }

    // ── Daily stats ───────────────────────────────────────────────────────────

    pub async fn get_daily_stats(&self, user_id: &str, date: &str) -> Result<DailyStats> {
        let parent = self.db.parent_path("users", user_id)?;
        Ok(self
            .db
            .fluent()
            .select()
            .by_id_in("dailyStats")
            .parent(&parent)
            .obj::<DailyStats>()
            .one(date)
            .await
            .context("get_daily_stats")?
            .unwrap_or_default())
    }

    // ── Food catalog ──────────────────────────────────────────────────────────

    pub async fn get_food_catalog(&self, user_id: &str) -> Result<Vec<FoodCatalogItem>> {
        let parent = self.db.parent_path("users", user_id)?;
        Ok(self
            .db
            .fluent()
            .select()
            .by_id_in("meta")
            .parent(&parent)
            .obj::<FoodCatalogDoc>()
            .one("foodCatalog")
            .await
            .context("get_food_catalog")?
            .unwrap_or_default()
            .items)
    }

    // ── Weight history ────────────────────────────────────────────────────────

    pub async fn create_weight_history(
        &self,
        user_id: &str,
        weight_kg: f64,
        source: &str,
    ) -> Result<()> {
        let col = format!("users/{}/weightHistory", user_id);
        let entry = WeightHistoryEntry {
            weight_kg,
            recorded_at: now_timestamp(),
            source: source.to_string(),
        };
        self.db
            .fluent()
            .insert()
            .into(&col)
            .generate_document_id()
            .object(&entry)
            .execute::<WeightHistoryEntry>()
            .await
            .context("create_weight_history")?;
        Ok(())
    }

    // ── AI recommendations ────────────────────────────────────────────────────

    pub async fn save_ai_recommendation(
        &self,
        user_id: &str,
        date: &str,
        doc: Value,
    ) -> Result<()> {
        let col = format!("users/{}/aiRecommendations", user_id);
        self.db
            .fluent()
            .update()
            .in_col(&col)
            .document_id(date)
            .object(&doc)
            .execute::<Value>()
            .await
            .context("save_ai_recommendation")?;
        Ok(())
    }

    pub async fn list_ai_recommendations(
        &self,
        user_id: &str,
        limit: i64,
    ) -> Result<Vec<AiRecommendationSummaryItem>> {
        let parent = self.db.parent_path("users", user_id)?;
        let docs: Vec<Value> = self
            .db
            .fluent()
            .select()
            .from("aiRecommendations")
            .parent(&parent)
            .limit(limit as u32)
            .order_by([("__name__", FirestoreQueryDirection::Descending)])
            .obj::<Value>()
            .stream_query_with_errors()
            .await?
            .try_collect()
            .await?;

        let items = docs
            .into_iter()
            .filter_map(|doc| {
                let date = doc["date"].as_str().unwrap_or_default().to_string();
                if date.is_empty() {
                    return None;
                }
                Some(AiRecommendationSummaryItem {
                    date,
                    saved_at: doc["savedAt"].as_str().unwrap_or_default().to_string(),
                    status: doc["status"].as_str().unwrap_or_default().to_string(),
                    summary_message: doc["summaryMessage"]
                        .as_str()
                        .unwrap_or_default()
                        .to_string(),
                    recommended_calorie_target: doc["recommendedCalorieTarget"]
                        .as_f64()
                        .unwrap_or(0.0),
                    weight_kg: doc["bodySnapshot"]["weightKg"].as_f64().unwrap_or(0.0),
                })
            })
            .collect();
        Ok(items)
    }

    pub async fn get_ai_recommendation_by_date(
        &self,
        user_id: &str,
        date: &str,
    ) -> Result<Option<AiRecommendationDetail>> {
        let parent = self.db.parent_path("users", user_id)?;
        self.db
            .fluent()
            .select()
            .by_id_in("aiRecommendations")
            .parent(&parent)
            .obj::<AiRecommendationDetail>()
            .one(date)
            .await
            .context("get_ai_recommendation_by_date")
    }
}
