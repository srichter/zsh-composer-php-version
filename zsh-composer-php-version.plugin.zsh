function _available_php_versions {
    echo $(update-alternatives --list php | grep -o '[0-9]\.[0-9]')
}

function _set_php_version {
    sudo update-alternatives --quiet --set php "/usr/bin/php${1}"
    sudo update-alternatives --quiet --set php-config "/usr/bin/php-config${1}"
    sudo update-alternatives --quiet --set phpize "/usr/bin/phpize${1}"
}

function _composer_php_version {
    if [[ -f "$1/composer.json" ]]; then
        local REQUIRED_PHP=$(cat "$1/composer.json" | jq -r '.require.php' | sed -e 's/|/||/')
        local AVAILABLE_PHP=$(_available_php_versions)
        local SEMVER_PHP=$("$_ZSH_COMPOSER_PHP_VERSION_PLUGIN_DIR/sh-semver/semver.sh" -r "$REQUIRED_PHP" "$AVAILABLE_PHP" | tail -n1)
        echo $SEMVER_PHP
    fi
}

function _php_workon_cwd {
    if [[ -z "$WORKON_CWD" ]]; then
        local WORKON_CWD=1

        # Get absolute path, resolving symlinks
        local PROJECT_ROOT="${PWD:A}"
        while [[ "$PROJECT_ROOT" != "/" && ! -e "$PROJECT_ROOT/composer.json" && ! -e "$PROJECT_ROOT/.phpenv-version" ]]; do
            PROJECT_ROOT="${PROJECT_ROOT:h}"
        done

        local PROJECT_NAME="${PROJECT_ROOT:t}"

        if [[ -n $CD_PHP_PROJECT ]]; then
            if [[ "$PROJECT_NAME" != "$CD_PHP_PROJECT" ]]; then
                # We've left the project, swap php back
                _set_php_version "$CD_PHP_VERSION" && unset CD_PHP_PROJECT CD_PHP_VERSION
            else
                # We're still in the project, no need to check the PHP version again
                return
            fi
        fi

        if [[ -z $PROJECT_NAME ]]; then
            # We're not in a PHP project
            return
        fi

        # Check for override
        if [[ -f "$PROJECT_ROOT/.phpenv-version" ]]; then
            local PHP_VERSION="$(cat "$PROJECT_ROOT/.phpenv-version")"
            local AVAILABLE_PHP=$(_available_php_versions)
            if [[ $AVAILABLE_PHP[(Ie)$PHP_VERSION] -eq 0 ]]; then
                print "PHP version specified in .phpenv-version ($PHP_VERSION) is not available!" >&2
                return 1
            fi
        else
            local PHP_VERSION="$(_composer_php_version "$PROJECT_ROOT")"
        fi

        if [[ -n $PHP_VERSION && -n $PROJECT_NAME ]]; then
            # Swap the PHP version only if needed
            CURRENT_PHP=$(php-config --version | cut -d. -f1,2)
            if [[ "$CURRENT_PHP" != "$PHP_VERSION" ]]; then
                _set_php_version "$PHP_VERSION" && export CD_PHP_VERSION="$CURRENT_PHP" CD_PHP_PROJECT="$PROJECT_NAME"
            fi
        fi
    fi
}

_ZSH_COMPOSER_PHP_VERSION_PLUGIN_DIR="${0:A:h}"

autoload -U add-zsh-hook
add-zsh-hook chpwd _php_workon_cwd
