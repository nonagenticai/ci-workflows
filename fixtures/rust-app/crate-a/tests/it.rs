// An integration TARGET, not just an inline module: `--all-targets` is what makes the preflight
// a compile gate, and a separate test target is the shape a real workspace's type errors hide in.

use rust_app_a::increment;

#[test]
fn integration_target_compiles() {
    assert_eq!(increment(41), 42);
}
