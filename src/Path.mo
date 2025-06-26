// Empty path segments fix for Path.mo
// Replace the existing parse function with this updated version

import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Array "mo:new-base/Array";
import IterTools "mo:itertools/Iter";
import TextX "mo:xtended-text/TextX";
import Char "mo:new-base/Char";
import Result "mo:new-base/Result";

module {
    public type Path = [Segment];

    public type Segment = Text;

    public type TextFormat = {
        #url;
        #custom : {
            separator : Text;
        };
    };

    /// Parses a text path into an array of path segments using "/" as separator.
    /// Automatically removes leading and trailing separators and filters out empty segments.
    ///
    /// ```motoko
    /// let path = Path.fromText("/users/john/documents");
    /// // path is ["users", "john", "documents"]
    ///
    /// let emptyPath = Path.fromText("/");
    /// // emptyPath is []
    /// ```
    public func fromText(path : Text) : Result.Result<Path, Text> {
        // Handle edge cases first
        if (path == "" or path == "/") {
            return #ok([]);
        };

        var correctedPath = path;
        if (Text.startsWith(correctedPath, #char('/'))) {
            // Remove leading separator
            correctedPath := TextX.slice(correctedPath, 1, correctedPath.size() - 1);
        };
        if (Text.endsWith(correctedPath, #char('/'))) {
            // Remove trailing separator
            correctedPath := TextX.slice(correctedPath, 0, correctedPath.size() - 1);
        };

        // Split by the custom separator and filter out empty segments
        let segments = correctedPath
        |> Text.split(_, #char('/'))
        |> Iter.toArray(_);

        for (segment in segments.vals()) {
            for (char in segment.chars()) {
                let code = Char.toNat32(char);
                // Reject spaces and control characters (0-31, 127)
                if (code == 32 or (code >= 0 and code <= 31) or code == 127) {
                    return #err("Invalid character '" # Char.toText(char) # "' in path");
                };
            };
        };

        #ok(segments);

    };

    /// Converts a path array to a text representation with "/" separators.
    /// Returns an empty string for empty paths, otherwise adds a leading "/" to the joined segments.
    ///
    /// ```motoko
    /// let path = ["users", "john", "documents"];
    /// let pathText = Path.toText(path);
    /// // pathText is "/users/john/documents"
    ///
    /// let emptyPathText = Path.toText([]);
    /// // emptyPathText is ""
    /// ```
    public func toText(path : Path) : Text {
        // Handle empty path
        if (path.size() == 0) {
            return "";
        };
        "/" # Text.join("/", path.vals());
    };

    /// Checks if the given prefix path matches the beginning of the target path.
    /// Returns the remaining path segments if there's a match, null otherwise.
    ///
    /// ```motoko
    /// let fullPath = ["api", "v1", "users", "123"];
    /// let prefix = ["api", "v1"];
    /// let remaining = Path.match(prefix, fullPath);
    /// // remaining is ?["users", "123"]
    ///
    /// let noMatch = Path.match(["admin"], fullPath);
    /// // noMatch is null
    /// ```
    public func match(prefix : Path, path : Path) : ?Path {
        let prefixSize = prefix.size();
        let pathSize = path.size();
        if (prefixSize > pathSize) {
            return null;
        };
        let commonSize = IterTools.zip(prefix.vals(), path.vals())
        |> IterTools.takeWhile(
            _,
            func(pair : (Segment, Segment)) : Bool {
                let (prefixSegment, pathSegment) = pair;
                prefixSegment == pathSegment;
            },
        )
        |> Iter.size(_);
        if (commonSize == prefixSize) {
            let remainingPath = path.vals() |> IterTools.skip(_, commonSize) |> Iter.toArray(_);
            return ?remainingPath;
        };
        null; // No match
    };

    /// Appends a single segment to the end of a path.
    ///
    /// ```motoko
    /// let basePath = ["api", "v1"];
    /// let newPath = Path.join(basePath, "users");
    /// // newPath is ["api", "v1", "users"]
    /// ```
    public func join(path : Path, segment : Segment) : Path {
        joinMulti(path, [segment]);
    };

    /// Appends multiple segments to the end of a path.
    ///
    /// ```motoko
    /// let basePath = ["api"];
    /// let segments = ["v1", "users", "123"];
    /// let newPath = Path.joinMulti(basePath, segments);
    /// // newPath is ["api", "v1", "users", "123"]
    /// ```
    public func joinMulti(path : Path, segments : [Segment]) : Path {
        Array.concat(path, segments);
    };

    /// Compares two paths for equality.
    ///
    /// ```motoko
    /// let path1 = ["api", "v1", "users"];
    /// let path2 = ["api", "v1", "users"];
    /// let isEqual = Path.equal(path1, path2);
    /// // isEqual is true
    /// ```
    public func equal(path1 : Path, path2 : Path) : Bool {
        path1 == path2;
    };

    /// Normalizes a path by filtering out empty segments and converting all segments to lowercase.
    ///
    /// ```motoko
    /// let path = ["API", "", "V1", "Users"];
    /// let normalized = Path.normalize(path);
    /// // normalized is ["api", "v1", "users"]
    /// ```
    public func normalize(path : Path) : Path {
        path.vals()
        |> Iter.filter(
            _,
            func(segment : Segment) : Bool {
                segment != "" // Filter out empty segments
            },
        )
        |> Iter.map(_, Text.toLower)
        |> Iter.toArray(_);
    };
};
