#!/usr/bin/env bash
###############################################################################
# run-tests.sh
#
# Script unifié d'exécution des tests unitaires. Il s'adapte automatiquement
# au type de projet rencontré :
#   - Projet Node/Angular  -> détecté via package.json  -> `npm test` (Karma)
#   - Projet Java/Gradle   -> détecté via gradlew/build.gradle -> `./gradlew test`
#
# Chaque projet produit un rapport JUnit XML, collecté dans test-results/,
# directement exploitable par GitHub Actions (action de publication de tests).
#
# Usage :
#   ./run-tests.sh [DOSSIER_PROJET ...]
#   ./run-tests.sh                 # teste le projet courant (.)
#   ./run-tests.sh . ../backend    # teste plusieurs projets (front + back)
#
# Code de sortie : 0 si tous les projets passent, 1 si au moins un échoue.
###############################################################################

set -euo pipefail

# --- Constantes & couleurs -------------------------------------------------
RESULTS_DIR="test-results"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'
  BLUE=$'\033[0;34m'; BOLD=$'\033[1m'; NC=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; NC=""
fi

log()   { printf '%s[run-tests]%s %s\n'        "$BLUE"   "$NC" "$*"; }
ok()    { printf '%s[run-tests] ✔%s %s\n'      "$GREEN"  "$NC" "$*"; }
warn()  { printf '%s[run-tests] ⚠%s %s\n'      "$YELLOW" "$NC" "$*" >&2; }
error() { printf '%s[run-tests] x%s %s\n'       "$RED"    "$NC" "$*" >&2; }

# Vérifie qu'une commande est disponible, sinon échoue proprement.
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Dépendance manquante : '$1' est introuvable dans le PATH."
    return 1
  fi
}

###############################################################################
# Tests d'un projet Node / Angular (npm + Karma)
###############################################################################
run_npm_tests() {
  local dir="$1"
  local project_results="$2"

  log "Projet Node/Angular détecté dans '$dir'."
  require_cmd node
  require_cmd npm

  pushd "$dir" >/dev/null

  # Point de vigilance : vérifier l'existence des dépendances avant de tester.
  if [[ ! -d node_modules ]]; then
    warn "node_modules absent — installation des dépendances (npm ci)…"
    if [[ -f package-lock.json ]]; then
      npm ci
    else
      npm install
    fi
  fi

  # Nettoyage des artefacts d'un éventuel run précédent côté projet.
  rm -rf reports

  # Karma écrit le JUnit XML dans le dossier indiqué par JUNIT_OUTPUT_DIR.
  # ChromeHeadless est requis : on aide Karma à trouver le binaire si besoin.
  export JUNIT_OUTPUT_DIR="$project_results"
  : "${CHROME_BIN:=$(command -v google-chrome || command -v chromium || command -v chrome || true)}"
  export CHROME_BIN

  local status=0
  npm test || status=$?

  popd >/dev/null
  return $status
}

###############################################################################
# Tests d'un projet Java / Gradle
###############################################################################
run_gradle_tests() {
  local dir="$1"
  local project_results="$2"

  log "Projet Java/Gradle détecté dans '$dir'."

  pushd "$dir" >/dev/null

  # Point de vigilance : vérifier la présence du wrapper / de Gradle.
  local gradle_cmd
  if [[ -f gradlew ]]; then
    chmod +x gradlew 2>/dev/null || true
    gradle_cmd="./gradlew"
  elif command -v gradle >/dev/null 2>&1; then
    warn "Wrapper gradlew absent — utilisation du Gradle système."
    gradle_cmd="gradle"
  else
    error "Ni './gradlew' ni 'gradle' disponibles pour '$dir'."
    popd >/dev/null
    return 1
  fi

  # Nettoyage des résultats de tests précédents.
  rm -rf build/test-results/test

  local status=0
  "$gradle_cmd" test || status=$?

  # Collecte des rapports JUnit générés par Gradle.
  if compgen -G "build/test-results/test/*.xml" >/dev/null; then
    cp build/test-results/test/*.xml "$project_results"/
  else
    warn "Aucun rapport JUnit trouvé sous build/test-results/test/."
  fi

  popd >/dev/null
  return $status
}

###############################################################################
# Détection automatique du type de projet puis exécution
###############################################################################
run_project() {
  local dir="$1"

  if [[ ! -d "$dir" ]]; then
    error "Dossier projet introuvable : '$dir'."
    return 1
  fi

  # Dossier de résultats dédié au projet (évite les collisions multi-projets).
  local name project_results
  name="$(basename "$(cd "$dir" && pwd)")"
  project_results="${SCRIPT_DIR}/${RESULTS_DIR}/${name}"
  mkdir -p "$project_results"

  printf '\n%s=== Tests : %s ===%s\n' "$BOLD" "$name" "$NC"

  if [[ -f "$dir/package.json" ]]; then
    run_npm_tests "$dir" "$project_results"
  elif [[ -f "$dir/build.gradle" || -f "$dir/build.gradle.kts" || -f "$dir/gradlew" ]]; then
    run_gradle_tests "$dir" "$project_results"
  else
    error "Type de projet non reconnu dans '$dir' (ni package.json ni Gradle)."
    return 1
  fi
}

###############################################################################
# Point d'entrée
###############################################################################
main() {
  # Par défaut, on teste le projet courant ; sinon la liste fournie en argument.
  local targets=("$@")
  if [[ ${#targets[@]} -eq 0 ]]; then
    targets=(".")
  fi

  # Point de vigilance : nettoyer les artefacts des runs précédents.
  log "Nettoyage du dossier '${RESULTS_DIR}/'…"
  rm -rf "${SCRIPT_DIR:?}/${RESULTS_DIR}"
  mkdir -p "${SCRIPT_DIR}/${RESULTS_DIR}"

  local overall=0
  local summary=()
  for target in "${targets[@]}"; do
    if run_project "$target"; then
      summary+=("${GREEN}PASS${NC}  $target")
    else
      overall=1
      summary+=("${RED}FAIL${NC}  $target")
    fi
  done

  # Récapitulatif et code de sortie global.
  printf '\n%s=== Récapitulatif ===%s\n' "$BOLD" "$NC"
  for line in "${summary[@]}"; do
    printf '  %b\n' "$line"
  done
  printf 'Rapports JUnit : %s%s/%s\n' "$BOLD" "$RESULTS_DIR" "$NC"

  if [[ $overall -eq 0 ]]; then
    ok "Tous les tests sont passés."
  else
    error "Au moins un projet a échoué."
  fi
  return $overall
}

main "$@"
