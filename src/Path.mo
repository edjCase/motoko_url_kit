// Empty path segments fix for Path.mo
// Replace the existing parse function with this updated version

import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Array "mo:new-base/Array";
import IterTools "mo:itertools/Iter";

module {
    public type Path = [Segment];

    public type Segment = Text;

    public type TextFormat = {
        #url;
        #custom : {
            separator : Text;
        };
    };

    public func fromText(path : Text) : Path = fromTextWithSeparator(path, "/");

    public func fromTextWithSeparator(path : Text, separator : Text) : Path {
        // Handle edge cases first
        if (path == "" or path == separator) {
            return [];
        };

        // Split by the custom separator and filter out empty segments
        path
        |> Text.split(_, #text(separator))
        |> Iter.filter(_, func(x : Text) : Bool { x != "" })
        |> Iter.toArray(_);
    };

    public func toText(path : Path) : Text {
        toTextWithSeparator(path, "/");
    };

    public func toTextWithSeparator(path : Path, separator : Text) : Text {
        // Handle empty path
        if (path.size() == 0) {
            return "";
        };
        "/" # Text.join(separator, path.vals());
    };

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

    public func join(path : Path, segment : Segment) : Path {
        joinMulti(path, [segment]);
    };

    public func joinMulti(path : Path, segments : [Segment]) : Path {
        Array.concat(path, segments);
    };

    public func equal(path1 : Path, path2 : Path) : Bool {
        path1 == path2;
    };

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
