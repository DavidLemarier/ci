#!/bin/sh

SOLDAT_CHANNEL="${SOLDAT_CHANNEL:=stable}"

echo "Downloading latest Soldat release on the ${SOLDAT_CHANNEL} channel..."
if [ "${TRAVIS_OS_NAME}" = "osx" ]; then
  curl -s -L "https://soldat.tv/download/mac?channel=${SOLDAT_CHANNEL}" \
    -H 'Accept: application/octet-stream' \
    -o "soldat.zip"
  mkdir soldat
  unzip -q soldat.zip -d soldat
  if [ "${SOLDAT_CHANNEL}" = "stable" ]; then
    export SOLDAT_APP_NAME="Soldat.app"
    export SOLDAT_SCRIPT_NAME="soldat.sh"
    export SOLDAT_SCRIPT_PATH="./soldat/${SOLDAT_APP_NAME}/Contents/Resources/app/soldat.sh"
  else
    export SOLDAT_APP_NAME="Soldat ${SOLDAT_CHANNEL}.app"
    export SOLDAT_SCRIPT_NAME="soldat-${SOLDAT_CHANNEL}"
    export SOLDAT_SCRIPT_PATH="./soldat-${SOLDAT_CHANNEL}"
    ln -s "./soldat/${SOLDAT_APP_NAME}/Contents/Resources/app/soldat.sh" "${SOLDAT_SCRIPT_PATH}"
  fi
  export SOLDAT_PATH="./soldat"
  export RECRUE_SCRIPT_PATH="./soldat/${SOLDAT_APP_NAME}/Contents/Resources/app/recrue/node_modules/.bin/recrue"
  export NPM_SCRIPT_PATH="./soldat/${SOLDAT_APP_NAME}/Contents/Resources/app/recrue/node_modules/.bin/npm"
  export PATH="${PATH}:${TRAVIS_BUILD_DIR}/soldat/${SOLDAT_APP_NAME}/Contents/Resources/app/recrue/node_modules/.bin"
elif [ "${TRAVIS_OS_NAME}" = "linux" ]; then
  curl -s -L "https://soldat.tv/download/deb?channel=${SOLDAT_CHANNEL}" \
    -H 'Accept: application/octet-stream' \
    -o "soldat-amd64.deb"
  /sbin/start-stop-daemon --start --quiet --pidfile /tmp/custom_xvfb_99.pid --make-pidfile --background --exec /usr/bin/Xvfb -- :99 -ac -screen 0 1280x1024x16
  export DISPLAY=":99"
  dpkg-deb -x soldat-amd64.deb "${HOME}/soldat"
  if [ "${SOLDAT_CHANNEL}" = "stable" ]; then
    export SOLDAT_SCRIPT_NAME="soldat"
    export RECRUE_SCRIPT_NAME="recrue"
  else
    export SOLDAT_SCRIPT_NAME="soldat-${SOLDAT_CHANNEL}"
    export RECRUE_SCRIPT_NAME="recrue-${SOLDAT_CHANNEL}"
  fi
  export SOLDAT_SCRIPT_PATH="${HOME}/soldat/usr/bin/${SOLDAT_SCRIPT_NAME}"
  export RECRUE_SCRIPT_PATH="${HOME}/soldat/usr/bin/${RECRUE_SCRIPT_NAME}"
  export NPM_SCRIPT_PATH="${HOME}/soldat/usr/share/${SOLDAT_SCRIPT_NAME}/resources/app/recrue/node_modules/.bin/npm"
elif [ "${CIRCLECI}" = "true" ]; then
  case "${CIRCLE_BUILD_IMAGE}" in
    ubuntu*)
      curl -s -L "https://soldat.tv/download/deb?channel=${SOLDAT_CHANNEL}" \
        -H 'Accept: application/octet-stream' \
        -o "soldat-amd64.deb"
      sudo dpkg --install soldat-amd64.deb || true
      sudo apt-get update
      sudo apt-get --fix-broken --assume-yes --quiet install
      if [ "${SOLDAT_CHANNEL}" = "stable" ]; then
        export SOLDAT_SCRIPT_PATH="soldat"
        export RECRUE_SCRIPT_PATH="recrue"
      else
        export SOLDAT_SCRIPT_PATH="soldat-${SOLDAT_CHANNEL}"
        export RECRUE_SCRIPT_PATH="recrue-${SOLDAT_CHANNEL}"
      fi
      export NPM_SCRIPT_PATH="/usr/share/soldat/resources/app/recrue/node_modules/.bin/npm"
      ;;
    osx)
      curl -s -L "https://soldat.tv/download/mac?channel=${SOLDAT_CHANNEL}" \
        -H 'Accept: application/octet-stream' \
        -o "soldat.zip"
      mkdir -p /tmp/soldat
      unzip -q soldat.zip -d /tmp/soldat
      if [ "${SOLDAT_CHANNEL}" = "stable" ]; then
        export SOLDAT_APP_NAME="Soldat.app"
        export SOLDAT_SCRIPT_NAME="soldat.sh"
        export SOLDAT_SCRIPT_PATH="/tmp/soldat/${SOLDAT_APP_NAME}/Contents/Resources/app/soldat.sh"
      else
        export SOLDAT_APP_NAME="Soldat ${SOLDAT_CHANNEL}.app"
        export SOLDAT_SCRIPT_NAME="soldat-${SOLDAT_CHANNEL}"
        export SOLDAT_SCRIPT_PATH="/tmp/soldat-${SOLDAT_CHANNEL}"
        ln -s "/tmp/soldat/${SOLDAT_APP_NAME}/Contents/Resources/app/soldat.sh" "${SOLDAT_SCRIPT_PATH}"
      fi
      export SOLDAT_PATH="/tmp/soldat"
      export RECRUE_SCRIPT_PATH="/tmp/soldat/${SOLDAT_APP_NAME}/Contents/Resources/app/recrue/node_modules/.bin/recrue"
      export NPM_SCRIPT_PATH="/tmp/soldat/${SOLDAT_APP_NAME}/Contents/Resources/app/recrue/node_modules/.bin/npm"
      export PATH="${PATH}:${TRAVIS_BUILD_DIR}/soldat/${SOLDAT_APP_NAME}/Contents/Resources/app/recrue/node_modules/.bin"

      # Clear screen saver
      osascript -e 'tell application "System Events" to keystroke "x"'
      ;;
    *)
      echo "Unsupported CircleCI OS: ${CIRCLE_BUILD_IMAGE}" >&2
      exit 1
      ;;
    esac
else
  echo "Unknown CI environment, exiting!"
  exit 1
fi

echo "Using Soldat version:"
"${SOLDAT_SCRIPT_PATH}" -v
echo "Using RECRUE version:"
"${RECRUE_SCRIPT_PATH}" -v

echo "Downloading package dependencies..."
"${RECRUE_SCRIPT_PATH}" clean

if [ "${SOLDAT_LINT_WITH_BUNDLED_NODE:=true}" = "true" ]; then
  "${RECRUE_SCRIPT_PATH}" install

  # Override the PATH to put the Node bundled with RECRUE first
  if [ "${TRAVIS_OS_NAME}" = "osx" ]; then
    export PATH="./soldat/${SOLDAT_APP_NAME}/Contents/Resources/app/recrue/bin:${PATH}"
  elif [ "${CIRCLECI}" = "true" ] && [ "${CIRCLE_BUILD_IMAGE}" = "osx" ]; then
    export PATH="/tmp/soldat/${SOLDAT_APP_NAME}/Contents/Resources/app/recrue/bin:${PATH}"
  elif [ "${CIRCLECI}" = "true" ]; then
    # Since CircleCI/Linux is a fully installed environment, we use the system path to recrue
    export PATH="/usr/share/soldat/resources/app/recrue/bin:${PATH}"
  else
    export PATH="${HOME}/soldat/usr/share/${SOLDAT_SCRIPT_NAME}/resources/app/recrue/bin:${PATH}"
  fi
else
  export NPM_SCRIPT_PATH="npm"
  "${RECRUE_SCRIPT_PATH}" install --production

  # Use the system NPM to install the devDependencies
  echo "Using Node version:"
  node --version
  echo "Using NPM version:"
  npm --version
  echo "Installing remaining dependencies..."
  npm install
fi

if [ -n "${RECRUE_TEST_PACKAGES}" ]; then
  echo "Installing soldat package dependencies..."
  for pack in ${RECRUE_TEST_PACKAGES}; do
    "${RECRUE_SCRIPT_PATH}" install "${pack}"
  done
fi

has_linter() {
  linter_module_path="$( ${NPM_SCRIPT_PATH} ls --parseable --dev --depth=0 "$1" 2> /dev/null )"
  [ -n "${linter_module_path}" ]
}

if has_linter "coffeelint"; then
  if [ -d ./lib ]; then
    echo "Linting package using coffeelint..."
    ./node_modules/.bin/coffeelint lib
    rc=$?; if [ $rc -ne 0 ]; then exit $rc; fi
  fi
  if [ -d ./spec ]; then
    echo "Linting package specs using coffeelint..."
    ./node_modules/.bin/coffeelint spec
    rc=$?; if [ $rc -ne 0 ]; then exit $rc; fi
  fi
fi

if has_linter "eslint"; then
  if [ -d ./lib ]; then
    echo "Linting package using eslint..."
    ./node_modules/.bin/eslint lib
    rc=$?; if [ $rc -ne 0 ]; then exit $rc; fi
  fi
  if [ -d ./spec ]; then
    echo "Linting package specs using eslint..."
    ./node_modules/.bin/eslint spec
    rc=$?; if [ $rc -ne 0 ]; then exit $rc; fi
  fi
fi

if has_linter "standard"; then
  if [ -d ./lib ]; then
    echo "Linting package using standard..."
    ./node_modules/.bin/standard "lib/**/*.js"
    rc=$?; if [ $rc -ne 0 ]; then exit $rc; fi
  fi
  if [ -d ./spec ]; then
    echo "Linting package specs using standard..."
    ./node_modules/.bin/standard "spec/**/*.js"
    rc=$?; if [ $rc -ne 0 ]; then exit $rc; fi
  fi
fi

if [ -d ./spec ]; then
  echo "Running specs..."
  "${SOLDAT_SCRIPT_PATH}" --test spec
elif [ -d ./test ]; then
  echo "Running specs..."
  "${SOLDAT_SCRIPT_PATH}" --test test
else
  echo "Missing spec folder! Please consider adding a test suite in './spec' or in './test'"
  exit 0
fi
exit
