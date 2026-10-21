import Foundation

/// Picks out the entries a log query returns that earlier queries haven't.
///
/// `OSLogStore` can't query "only what's new": every query returns everything since the
/// process started. The cursor remembers the newest timestamp it
/// has seen and how many entries carried exactly that timestamp, so ties aren't lost or
/// repeated. It relies on each query returning entries in chronological order.
struct IncrementalCursor {
    private(set) var lastDate: Date?
    private(set) var countAtLastDate = 0

    mutating func newElements<S: Sequence>(in elements: S, date: (S.Element) -> Date) -> [S.Element] {
        var result: [S.Element] = []
        var seenAtLastDate = 0
        var newestDate: Date?
        var countAtNewestDate = 0

        for element in elements {
            let d = date(element)

            if newestDate == nil || d > newestDate! {
                newestDate = d
                countAtNewestDate = 1
            } else if d == newestDate {
                countAtNewestDate += 1
            }

            if let lastDate {
                if d < lastDate { continue }
                if d == lastDate {
                    seenAtLastDate += 1
                    if seenAtLastDate <= countAtLastDate { continue }
                }
            }
            result.append(element)
        }

        if let newestDate {
            lastDate = newestDate
            countAtLastDate = countAtNewestDate
        }
        return result
    }
}
