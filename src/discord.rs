use std::collections::HashMap;

use log::info;

use crate::danbooru::DanbooruPost;

pub struct DiscordClient {
    pub webhook: String,
    client: reqwest::Client,
}

impl DiscordClient {
    pub fn new(webhook: &str) -> Self {
        DiscordClient {
            webhook: webhook.to_string(),
            client: reqwest::Client::new(),
        }
    }

    pub async fn send_posts(&self, posts: Vec<DanbooruPost>) -> reqwest::Result<()> {
        let links = posts
            .into_iter()
            .map(|db| format!("https://danbooru.donmai.us/posts/{}", db.id))
            .rev()
            .collect::<Vec<_>>()
            .join("\n");

        info!("{links:?}");

        let mut payload = HashMap::new();
        payload.insert("content", &links);

        self.client
            .post(&self.webhook)
            .json(&payload)
            .send()
            .await?;

        Ok(())
    }
}
