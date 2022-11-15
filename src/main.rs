mod danbooru;
mod discord;
mod env;

use crate::danbooru::DanbooruClient;
use crate::env::AegirEnv;

use chrono::Datelike;
use clap::{arg, Parser};
use discord::DiscordClient;
use log::{error, info};

use securefmt::Debug;
use std::{collections::HashMap, error::Error, path::PathBuf};

#[derive(Parser, Debug)]
struct Args {
    #[arg(env = "AEGIR_ENV")]
    environment: PathBuf,
    #[arg(long, env = "DANBOORU_USERNAME")]
    username: Option<String>,
    #[arg(long, env = "DANBOORU_APIKEY")]
    api_key: Option<String>,
    #[arg(short, long)]
    dry: bool,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    setup_logging()?;

    let args = Args::parse();

    info!("Environment file: {:?}", args.environment);

    if !args.environment.exists() {
        error!("Environment file doesn't exist!");
        Err("ERROR")?
    }

    let auth = if let (Some(username), Some(api_key)) = (args.username, args.api_key) {
        Some((username, api_key))
    } else {
        None
    };

    let db_client = DanbooruClient::new(auth);

    let envs: HashMap<String, AegirEnv> =
        toml::from_str(&std::fs::read_to_string(args.environment)?)?;

    for e in envs.values() {
        info!("{e:?}");
    }

    let requests: Vec<_> = envs
        .into_values()
        .map(|value| handle_env(value, &db_client, args.dry))
        .collect();

    futures::future::try_join_all(requests).await?;

    Ok(())
}

async fn handle_env(env: AegirEnv, db_client: &DanbooruClient, dry: bool) -> reqwest::Result<()> {
    let posts = db_client.index(&env.tags, &env.limit).await?;
    let discord_client = DiscordClient::new(&env.webhook);

    let today = chrono::offset::Local::now()
        .weekday()
        .num_days_from_monday()
        .into();

    if env.days.contains(&-1) || env.days.contains(&today) {
        if !env.dry && !dry {
            discord_client.send_posts(posts).await?;
        } else {
            info!("env working on dry mode");
        }
    } else {
        info!("Day not selected");
    }

    Ok(())
}

fn setup_logging() -> Result<(), Box<dyn Error>> {
    let loglevel = if cfg!(debug_assertions) {
        log::LevelFilter::Debug
    } else {
        log::LevelFilter::Info
    };

    fern::Dispatch::new()
        .format(|out, message, record| {
            out.finish(format_args!(
                "{} [{}] {}",
                record.target(),
                record.level(),
                message
            ))
        })
        .level(loglevel)
        .level_for("hyper", log::LevelFilter::Info)
        .chain(std::io::stdout())
        .apply()?;

    Ok(())
}
