use log::{info, debug};
use serde::Deserialize;

pub struct DanbooruClient {
    auth: Option<(String, String)>,
}

#[derive(Deserialize, Debug)]
pub struct DanbooruPost {
    pub id: u32,
    pub fav_count: u32,
}


impl DanbooruClient {
    pub fn new(auth: Option<(String, String)>) -> Self {
        DanbooruClient {
            auth: auth.map(|a| (a.0, a.1)),
        }
    }

    pub async fn index<L: std::fmt::Display>(
        &self,
        tags: &Vec<String>,
        limit: &L,
    ) -> Result<Vec<DanbooruPost>, reqwest::Error> {
        let base_url = "https://danbooru.donmai.us/posts.json";
        let client = reqwest::Client::new();

        let mut request = client
            .get(base_url)
            .query(&[("limit", &limit.to_string()), ("tags", &tags.join(" "))])
            .header(reqwest::header::CONTENT_TYPE, "application/json");

        if let Some(a) = &self.auth {
            info!("Setting auth");
            request = request.basic_auth(&a.0, Some(&a.1));
        }

        debug!("{:?}", request);

        let result = request.send().await?;

        let result_text = result.text().await?;
        debug!("{:?}", &result_text);

        let decoded = serde_json::from_str::<Vec<DanbooruPost>>(&result_text).unwrap();

        Ok(decoded)
    }
}
