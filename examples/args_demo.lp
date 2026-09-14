// ==============================================================================
// 👑 LIPI EXAMPLE: COMMAND LINE ARGUMENTS (examples/args_demo.lp)
// ⚡ 100% Pure Lipi First 1.0.0
// ==============================================================================

fn main argc argv
    say "Args count: " + str(argc)
    i = 0
    while i < argc
        say "  argv[" + str(i) + "] = " + str(get(argv, i))
        i = i + 1
    say "Done!"
    return 0
