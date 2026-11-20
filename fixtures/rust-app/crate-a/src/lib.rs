//! Smallest workspace that still fails every step `rust-preflight.yml` owns.
//!
//! * `cargo fmt --all -- --check` has something to judge.
//! * `cargo clippy --all-targets -- -D warnings` compiles the lib, the unit-test module and the
//!   integration target under `tests/`, so a type error anywhere in the crate's test code is a
//!   red here — which is the whole point of running `--all-targets`.

/// Adds one, without panicking at the top of the range.
pub fn increment(n: u32) -> u32 {
    n.wrapping_add(1)
}

#[cfg(test)]
mod tests {
    use super::increment;

    #[test]
    fn increments() {
        assert_eq!(increment(1), 2);
    }
}
