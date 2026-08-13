# treefmt hook: validate that each .nu file parses.
# Nushell has no mature autoformatter yet (nufmt is alpha), so this is a
# parse check only. treefmt passes the files to check as arguments.
#
# nu-check is called as a builtin, in-process (no per-file subprocess). It is
# run inside a `for` loop, not `each`: nu-check misreports parse errors from
# within an `each` closure. `nu-check --debug` prints the diagnostic and raises
# on a parse failure, so try/catch turns that into a bool without aborting the
# loop, and we exit non-zero if any file failed.
def main [...files: string] {
  mut failed = false
  for f in $files {
    # treefmt passes paths relative to the tree root. nu-check resolves a
    # relative path against $env.FILE_PWD (here the wrapper's store dir, not
    # the repo), so expand against the process CWD first.
    let target = ($f | path expand --no-symlink)
    # nu-check --debug raises on a parse failure; catch it so one bad file
    # does not abort the run. The catch returns the rendered diagnostic (which
    # names the failure, e.g. "Unbalanced delimiter"); a clean parse yields
    # null. Run in a `for` loop, not `each`: nu-check misreports from within
    # an `each` closure.
    let err = (
      try {
        nu-check --debug $target | ignore
        null
      } catch {|e|
        $e.rendered? | default ($e.msg? | default "parse error")
      }
    )
    if $err != null {
      print -e $"nu-check: parse error in ($f)"
      print -e $err
      $failed = true
    }
  }
  if $failed { exit 1 }
}
