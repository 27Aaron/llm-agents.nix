# Run the updater library's unit tests (purl parser, purl fetcher, handlers,
# version policy). These are zero-dependency stdlib unittest modules; the flake
# check runs them so the fetcher's logic can't silently regress. Discovery
# picks up every scripts/updater/*_test.py, so new tests are included for free.
{
  pkgs,
  flake,
}:
pkgs.runCommand "updater-tests-check"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    cp -r ${flake}/scripts scripts
    chmod -R +w scripts
    cd scripts
    export HOME=$TMPDIR
    export PYTHONDONTWRITEBYTECODE=1
    python3 -m unittest discover -s updater -p '*_test.py' -t . -v
    touch $out
  ''
