# Contributing

Contributions to FlexiChains are very much welcome, either in the form of issues or pull requests!
If you'd like to discuss a potential new feature or improvement please also don't hesitate to open an issue.

In particular, I am very keen to to improve interoperability with the wider Julia ecosystem (e.g. via package extensions).
If you have a package that you think could benefit from some custom behaviour with FlexiChains please do reach out!

## Formatting

FlexiChains currently uses [Runic.jl](https://github.com/fredrikekre/Runic.jl/) for formatting.
This is enforced on GitHub CI.

## Tests

To run the tests you can run `julia --project=.` from the root of the repository, and then run `]test` from the REPL, much like any other Julia package.

Equivalently, you can also run

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

The tests in FlexiChains are also set up to work with [TestPicker.jl](https://github.com/theogf/TestPicker.jl) which allows you to run a subset of the tests by entering `!` at the Julia REPL.

FlexiChains contains some tests for plotting, which compare the output of the plotting functions against reference images.
The reference images are stored in `test/plots/images` and are part of the repository itself.

If these need to be updated (e.g. because FlexiChains' plotting functionality has changed, or because of changes in the underlying plotting libraries), the reference images can be updated by running

```
UPDATE_REFIMAGES=1 julia --project=. -e 'using Pkg; Pkg.test()'
```

This will skip all other tests and only rerun the plotting tests to update the reference images.
