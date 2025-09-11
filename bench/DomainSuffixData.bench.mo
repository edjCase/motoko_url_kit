import Bench "mo:bench";
import Nat "mo:core@1/Nat";
import Result "mo:core@1/Result";
import Runtime "mo:core@1/Runtime";
import ComprehensiveDomainParser "../src/ComprehensiveDomainParser";
import DomainSuffixData "../src/data/DomainSuffixData";

module {

  public func init() : Bench.Bench {

    let smallData = "a!>b>c!>(d>e!>(f*www,aaa),z),1";

    let bench = Bench.Bench();

    bench.name("Testing decompression of domain suffix data");
    bench.description("Benchmarking the decompression of domain suffix data into a usable map structure.");

    bench.rows([
      "small",
      "comprehensive",
    ]);

    bench.cols(["1", "10"]);

    bench.runner(
      func(row, col) {
        let ?n = Nat.fromText(col) else Runtime.trap("Cols must only contain numbers: " # col);

        // Define the operation to perform based on the row
        let operation = switch (row) {
          case ("small") func(_ : Nat) : Result.Result<Any, Text> {
            ignore ComprehensiveDomainParser.decompressData(smallData);
            #ok;
          };
          case ("comprehensive") func(_ : Nat) : Result.Result<Any, Text> {
            ignore ComprehensiveDomainParser.decompressData(DomainSuffixData.value);
            #ok;
          };
          case (_) Runtime.trap("Unknown row: " # row);
        };

        // Single shared loop with result checking
        for (i in Nat.range(1, n + 1)) {
          switch (operation(i)) {
            case (#ok(_)) ();
            case (#err(e)) Runtime.trap(e);
          };
        };
      }
    );

    bench;
  };

};
