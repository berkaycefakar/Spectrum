# Spectrum

A music logging and social discovery app — rate songs and albums, add reviews, and see logs from people you follow in your feed. *Letterboxd for music.*

## Features

- **Song logging** — Search via iTunes, rate (0–5), pick a vibe color, add a review
- **Album rating** — Album page with community ratings and track list; rate and review in a separate sheet
- **Profile** — Your logs (Songs / Albums), stats, edit profile
- **Feed** — Logs from users you follow; or recent logs from everyone if you don’t follow anyone yet
- **User search & follow** — Search by username, view profile, follow / unfollow
- **Auth** — Email sign up / sign in; confirmation link opens in-app via deep link (`spectrum://auth-callback`)

## Tech Stack

- **SwiftUI** (iOS)
- **Supabase** — Auth, Postgres (profiles, reviews, album_reviews, follows)
- **iTunes Search API** — Song/album search and metadata

## Requirements

- Xcode 15+
- iOS 17+
- A Supabase project

## Setup

1. **Clone the repo**
   ```bash
   git clone https://github.com/YOUR_USERNAME/Spectrum.git
   cd Spectrum
   ```

2. **Open in Xcode**  
   Open `Spectrum.xcodeproj`; Swift packages (Supabase) will resolve automatically if needed.

3. **Supabase**
   - Create a project at [Supabase](https://supabase.com).
   - In **SQL Editor**, run in order:
     - `Supabase_migration_album_reviews.sql` — creates `album_reviews` table and RLS
     - `Supabase_fix_reviews_rating_constraint.sql` — sets `reviews.rating` to 0–10
   - In **Authentication → URL Configuration**, add this redirect URL:  
     `spectrum://auth-callback`
   - In Xcode, add **URL Types** (Target → Info): Scheme = `spectrum`

4. **API keys**  
   In `Spectrum/Services/SupabaseManager.swift`, set `supabaseURL` and `supabaseKey` to your Supabase project values. (The anon key is usually enough for development.)

5. **Build and run**  
   Choose a simulator or device and run (⌘R).

## Database

- **profiles** — Username, avatar, bio
- **reviews** — Song logs (itunes_track_id, rating 0–10, review_text, vibe_color)
- **album_reviews** — Album ratings (itunes_collection_id, rating 0–10, review_text)
- **follows** — Follower/following (follower_id, following_id)

RLS ensures users can only write their own data; read policies allow shared visibility where intended.

## License

This project is for personal or educational use.
