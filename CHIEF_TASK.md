# Chief Task: Spectrum App - Database & Feature Expansion

## Current State Analysis

**Existing Supabase Tables:**
- `profiles` (id, username, avatar_url, bio)
- `reviews` (id, user_id, itunes_track_id, spotify_track_id, rating, review_text, vibe_color, created_at)

**Frontend Features That Need Backend:**
1. Album ratings (AlbumDetailView has rating UI but doesn't save to Supabase)
2. Artist ratings/reviews (completely new feature)
3. User search (profiles table exists but no search function)
4. Friends/following system (needed for feed filtering)

## Required Tasks (Priority Order)

### Phase 1: Database Schema Extensions

1. **Add `album_reviews` table:**
   - id (UUID, primary key)
   - user_id (UUID, foreign key to profiles)
   - itunes_collection_id (Int64, album ID from iTunes)
   - rating (Int, 0-10 scale like track reviews)
   - review_text (text, nullable)
   - vibe_color (text)
   - created_at (timestamp)

2. **Add `artist_reviews` table:**
   - id (UUID, primary key)
   - user_id (UUID, foreign key to profiles)
   - artist_name (text, normalized)
   - rating (Int, 0-10 scale)
   - review_text (text, nullable)
   - vibe_color (text)
   - created_at (timestamp)

3. **Add `follows` table (for friends system):**
   - id (UUID, primary key)
   - follower_id (UUID, foreign key to profiles)
   - following_id (UUID, foreign key to profiles)
   - created_at (timestamp)
   - Unique constraint on (follower_id, following_id)

### Phase 2: SupabaseManager Extensions

Add methods to `SupabaseManager.swift`:

1. **Album Reviews:**
   - `saveAlbumReview(collectionId: Int64, rating: Int, text: String, vibeColor: String) async throws`
   - `getUserAlbumReviews(userId: UUID) async throws -> [AlbumReview]`
   - `getAlbumReviews(collectionId: Int64) async throws -> [AlbumReview]`

2. **Artist Reviews:**
   - `saveArtistReview(artistName: String, rating: Int, text: String, vibeColor: String) async throws`
   - `getUserArtistReviews(userId: UUID) async throws -> [ArtistReview]`
   - `getArtistReviews(artistName: String) async throws -> [ArtistReview]`

3. **User Search:**
   - `searchUsers(query: String) async throws -> [Profile]`

4. **Friends/Following:**
   - `followUser(userId: UUID) async throws`
   - `unfollowUser(userId: UUID) async throws`
   - `getFollowing(userId: UUID) async throws -> [Profile]`
   - `getFollowers(userId: UUID) async throws -> [Profile]`
   - `isFollowing(userId: UUID) async throws -> Bool`

5. **Feed:**
   - `fetchFollowingReviews(userId: UUID) async throws -> [Review]` (reviews from followed users)

### Phase 3: Model Extensions

Add to `SupabaseModels.swift`:

1. `AlbumReview` struct (similar to Review)
2. `ArtistReview` struct (similar to Review)
3. `Follow` struct (if needed)

### Phase 4: UI Updates

1. **AlbumDetailView:**
   - Wire up rating control to save to Supabase via `saveAlbumReview`
   - Show existing user rating if exists
   - Load and display community album reviews

2. **SearchDiscoveryView:**
   - Add "Users" section to search results
   - Show user cards with avatar, username, bio preview
   - Navigate to user profile on tap

3. **ProfileView:**
   - Add segmented control/tabs: "Songs", "Albums", "Artists"
   - Filter reviews by type
   - Sort each category by rating (highest to lowest)
   - Show empty states for each category

4. **FeedView:**
   - Change `fetchRecentReviews` to `fetchFollowingReviews` (or combine both)
   - Show reviews from followed users
   - If no follows, show recent reviews from all users (fallback)

5. **New: ArtistSearchView or integrate into SearchDiscoveryView:**
   - Search for artists
   - Show artist detail page with rating capability
   - Display artist's albums/tracks

### Phase 5: Implementation Notes

- All ratings use 0-10 integer scale (matching existing Review model)
- UI displays as 0-5 with 0.5 steps (convert: UI rating * 2 = DB rating)
- Use existing `vibeColor` palette
- Maintain dark neon glassmorphism aesthetic
- Add proper error handling and loading states
- Use async/await throughout

## Files to Create/Modify

**New Files:**
- `Spectrum/Models/AlbumReview.swift` (or add to SupabaseModels.swift)
- `Spectrum/Models/ArtistReview.swift` (or add to SupabaseModels.swift)
- `Spectrum/UI/Screens/ArtistDetailView.swift` (optional, or integrate into search)

**Modify:**
- `Spectrum/Models/SupabaseModels.swift` - Add new models
- `Spectrum/Services/SupabaseManager.swift` - Add new methods
- `Spectrum/UI/Screens/AlbumDetailView.swift` - Wire up saving
- `Spectrum/UI/Screens/SearchDiscoveryView.swift` - Add user search
- `Spectrum/UI/Screens/ProfileView.swift` - Add tabs and filtering
- `Spectrum/UI/Screens/FeedView.swift` - Show following reviews

## Testing Checklist

- [ ] Album ratings save and load correctly
- [ ] Artist ratings save and load correctly
- [ ] User search works and shows results
- [ ] Profile tabs filter correctly (Songs/Albums/Artists)
- [ ] Profile items sorted by rating (highest first)
- [ ] Feed shows following users' reviews
- [ ] Follow/unfollow functionality works
- [ ] All ratings display correctly (0-5 scale in UI)
