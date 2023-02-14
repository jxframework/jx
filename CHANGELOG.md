# Changelog

## v0.4.0 (2023-02-13)

* Implement support for plain variables in right-hand side of match expressions (e.g. `a = 10; j 10 = jx.(a)`)
* Add support for j-variables in `Function.identity/1` (e.g. `j 1 = Function.identity(jx.(1))`

## v0.3.0 (2023-02-03)

* Implement nested matching with initial support for `Kernel.*/2`, `Kernel.+/2`, and `Integer.pow/2` (e.g. `j 10 = jx.(2, jy.(2, 3))`)

## v0.2.0 (2023-01-29)

* Implement new search approach to allow better matching compared to previous greedy approach

## v0.1.1 (2023-01-25)

* Fix `j` macro to raise an error when invalid arguments are given

## v0.1.0 (2023-01-23)

First release.