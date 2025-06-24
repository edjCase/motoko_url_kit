import Result "mo:new-base/Result";
import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import VarArray "mo:new-base/VarArray";
import Nat32 "mo:new-base/Nat32";
import Nat8 "mo:new-base/Nat8";
import Char "mo:new-base/Char";
module {

    public type IpV4 = (Nat8, Nat8, Nat8, Nat8); // (192, 168, 1, 1)

    public func fromText(text : Text) : Result.Result<IpV4, Text> {
        let parts = Text.split(text, #text("."));
        let partsArray = Iter.toArray(parts);

        if (partsArray.size() != 4) return #err("IPv4 must have 4 octets");

        var octets : [var Nat8] = VarArray.repeat<Nat8>(0, 4);

        for (i in partsArray.keys()) {
            let part = partsArray[i];
            switch (parseNat8(part)) {
                case (#ok(octet)) octets[i] := octet;
                case (#err(msg)) return #err("Invalid octet '" # part # "': " # msg);
            };
        };

        #ok((octets[0], octets[1], octets[2], octets[3]));
    };

    public func toText(ip : IpV4) : Text {
        Nat8.toText(ip.0) # "." # Nat8.toText(ip.1) # "." # Nat8.toText(ip.2) # "." # Nat8.toText(ip.3);
    };

    private func parseNat8(text : Text) : Result.Result<Nat8, Text> {
        if (text.size() == 0) return #err("Empty octet");

        // Check for leading zeros (reject "01", "001", etc., but allow "0")
        if (text.size() > 1 and Text.startsWith(text, #char('0'))) {
            return #err("Leading zeros not allowed");
        };

        var result : Nat = 0;
        for (char in text.chars()) {
            if (char < '0' or char > '9') return #err("Non-numeric character");
            result := result * 10 + (Nat32.toNat(Char.toNat32(char)) - 48);
            if (result > 255) return #err("Value exceeds 255");
        };

        #ok(Nat8.fromNat(result));
    };
};
