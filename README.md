# Chess Engine (Muu)

I've been writing a chess engine for fun, one thing I'd like is the engine being capable of beating me. I think i have some decent abilities in chess,
on chess.com I have 2060 approx. so if I'm able to make a chess engine strong enough I'll be satisfied.

# Features

-   supports basic uci commands
    -   uci,
    -   isready
    -   position [fen | startpos] moves move1 ...
    -   go 
        - depth \<n>
        - perft \<n>

-   board representation: bitboards

# TODO

-   Improve move generation
-   Improve makeMove function readability
-   Time managment
-   Move ordering

# Prerequisites

You need zig 0.16.0 installed

# Clone and Compile Muu

<code>git clone https://github.com/molinete11/Chess_engine.git</code>

compile and run command: 

<code>zig build run -Doptimize=ReleaseFast</code>
