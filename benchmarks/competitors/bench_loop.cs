// ==============================================================================
// 🔷 C# BENCHMARK: 10,000,000 ARITHMETIC LOOP ITERATIONS (benchmarks/bench_loop.cs)
// ==============================================================================

using System;
using System.Diagnostics;

class Program
{
    static void Main()
    {
        var sw = Stopwatch.StartNew();

        ulong total = 0;
        for (ulong i = 1; i <= 10000000; i++)
        {
            total += (i % 7);
        }

        sw.Stop();
        double elapsedMs = sw.Elapsed.TotalMilliseconds;

        Console.WriteLine("C# Loop 10,000,000 Iterations Complete!");
        Console.WriteLine($"Sum: {total}");
        Console.WriteLine($"Elapsed Time: {elapsedMs:F2} ms");
    }
}
