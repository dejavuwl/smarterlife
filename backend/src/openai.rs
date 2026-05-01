use anyhow::{anyhow, Context, Result};
use serde_json::{json, Value};

use crate::state::AppState;

pub async fn call_openai_json(state: &AppState, messages: Vec<Value>) -> Result<String> {
    let body = json!({
        "model": "gpt-5.4",
        "messages": messages,
        "temperature": 0.4,
        "response_format": { "type": "json_object" }
    });
    let url = format!(
        "{}/v1/chat/completions",
        state.openai_base_url.trim_end_matches('/')
    );

    tracing::debug!(
        url = %url,
        model = "gpt-5.4",
        temperature = 0.4,
        message_count = messages.len(),
        messages = %serde_json::to_string(&messages).unwrap_or_default(),
        "sending LLM request"
    );

    let http_response = state
        .http
        .post(&url)
        .bearer_auth(&state.openai_api_key)
        .json(&body)
        .send()
        .await
        .context("failed to send OpenAI request")?;

    let status = http_response.status();
    tracing::debug!(status = %status, "received LLM HTTP response");

    let http_response = http_response
        .error_for_status()
        .context("OpenAI returned error status")?;

    let response = http_response
        .json::<Value>()
        .await
        .context("failed to parse OpenAI response")?;

    tracing::debug!(
        response = %serde_json::to_string(&response).unwrap_or_default(),
        "LLM response body"
    );

    let content = response["choices"][0]["message"]["content"]
        .as_str()
        .ok_or_else(|| anyhow!("no content in OpenAI response"))?
        .to_string();

    tracing::debug!(
        finish_reason = %response["choices"][0]["finish_reason"].as_str().unwrap_or("unknown"),
        prompt_tokens = response["usage"]["prompt_tokens"].as_u64().unwrap_or(0),
        completion_tokens = response["usage"]["completion_tokens"].as_u64().unwrap_or(0),
        total_tokens = response["usage"]["total_tokens"].as_u64().unwrap_or(0),
        content_length = content.len(),
        "LLM request complete"
    );

    Ok(content)
}
