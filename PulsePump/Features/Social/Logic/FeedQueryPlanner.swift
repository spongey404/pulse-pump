import Foundation

/// Builds the Firestore post queries for the feed, profiles and lift history.
///
/// The rules can only authorise a *query* on `posts` when it pins `authorUid` and an `audience` the
/// caller may see (visibility depends on other documents: follows and blocks). So:
/// - friends' posts are queried with `authorUid in [chunk]` and `audience in [everyone, friends]`,
///   in chunks small enough for Firestore's limit of 30 disjunctions (10 authors x 2 audiences = 20);
/// - my own posts are a separate query pinned to my uid (I may see all three audiences);
/// - blocked users are never queried (a block in either direction would make the rules reject
///   the whole chunk).
enum FeedQueryPlanner {
    static let pageSize = 20
    /// Authors per `in` query. 10 x 2 audiences = 20 disjunctions, under Firestore's limit of 30.
    static let chunkSize = 10
    /// What a non-owner may be shown from a friend.
    static let friendAudiences: [PostAudience] = [.everyone, .friends]

    /// Audiences I may read for `author`: all of them for me, `everyone + friends` for a friend,
    /// `everyone` for anybody else. An empty list means "no audience filter" (my own posts).
    static func audiences(for relationship: Relationship) -> [PostAudience] {
        switch relationship {
        case .me: []
        case .friends: friendAudiences
        default: [.everyone]
        }
    }

    /// The queries for one feed page: [friends + me], blocked users excluded, newest first.
    static func feedQueries(me: String, friends: Set<String>, blocked: Set<String>, before: Date?,
                            limit: Int = pageSize, chunkSize: Int = chunkSize) -> [PostQuery] {
        let others = friends.subtracting(blocked).subtracting([me]).sorted()
        var queries: [PostQuery] = stride(from: 0, to: others.count, by: max(1, chunkSize)).map { start in
            PostQuery(authorUids: Array(others[start..<min(start + max(1, chunkSize), others.count)]),
                      audiences: friendAudiences, before: before, limit: limit)
        }
        queries.append(PostQuery(authorUids: [me], audiences: [], before: before, limit: limit))
        return queries
    }

    /// One query per author: the fallback when the rules refuse multi-author `in` queries.
    static func perAuthor(_ query: PostQuery) -> [PostQuery] {
        query.authorUids.map { PostQuery(authorUids: [$0], audiences: query.audiences, before: query.before, limit: query.limit) }
    }

    /// Posts of one user as seen by me.
    static func profileQuery(author: String, relationship: Relationship, before: Date? = nil, limit: Int = 30) -> PostQuery {
        PostQuery(authorUids: [author], audiences: audiences(for: relationship), before: before, limit: limit)
    }

    /// Combines the pages of several queries into one newest-first page without duplicates, blocked
    /// authors or hidden posts.
    static func merge(_ pages: [[WorkoutFeedItem]], blocked: Set<String> = [], hidden: Set<String> = [], limit: Int = pageSize) -> [WorkoutFeedItem] {
        var seen = Set<String>()
        let all = pages.flatMap { $0 }
            .filter { !blocked.contains($0.userId) && !hidden.contains($0.id) && seen.insert($0.id).inserted }
            .sorted { ($0.createdAt, $0.id) > ($1.createdAt, $1.id) }
        return Array(all.prefix(limit))
    }
}
