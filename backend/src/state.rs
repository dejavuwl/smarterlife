use std::{collections::HashMap, sync::Arc, time::Instant};

use firestore::FirestoreDb;
use jsonwebtoken::DecodingKey;
use reqwest::Client;
use tokio::sync::RwLock;

pub struct FirebaseKeyCache {
    pub keys: HashMap<String, DecodingKey>,
    pub expires_at: Instant,
}

#[derive(Clone)]
pub struct AppState {
    pub http: Client,
    pub firestore: FirestoreDb,
    pub firebase_project_id: String,
    pub firebase_keys: Arc<RwLock<FirebaseKeyCache>>,
    pub openai_api_key: String,
    pub openai_base_url: String,
}
