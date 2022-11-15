use securefmt::Debug;
use serde::Deserialize;

#[derive(Deserialize, Debug)]
pub struct AegirEnv {
    pub days: Vec<i64>,
    pub dry: bool,
    pub limit: i32,
    pub phrase: String,
    pub tags: Vec<String>,
    #[sensitive]
    pub webhook: String,
}
