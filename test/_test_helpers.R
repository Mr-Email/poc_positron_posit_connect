# ============================================================================
# TEST FRAMEWORK HELPERS - Geschützt! Nicht ändern ohne Genehmigung
# ============================================================================

# Setup Test Environment
test_setup <- function() {
  unlink("data/raw", recursive = TRUE)
  unlink("output", recursive = TRUE)
  unlink("_targets", recursive = TRUE)
}

# Assertion Helpers
assert_equal <- function(actual, expected, message = "") {
  if (!isTRUE(all.equal(actual, expected))) {
    stop(glue::glue("ASSERTION FAILED: {message}\nExpected: {expected}\nActual: {actual}"))
  }
}

assert_true <- function(condition, message = "") {
  if (!isTRUE(condition)) {
    stop(glue::glue("ASSERTION FAILED: {message}"))
  }
}

assert_file_exists <- function(file_path, message = "") {
  if (!file.exists(file_path)) {
    stop(glue::glue("ASSERTION FAILED: File not found: {file_path}\n{message}"))
  }
}

# Test Result Formatter
test_result <- function(name, success, detail = "") {
  icon <- if (success) "✅" else "❌"
  cat(glue::glue("{icon} {name}: {detail}\n"))
  list(name = name, success = success)
}

# Test Header
print_test_header <- function(test_name, description) {
  cat(paste0("=", strrep("=", 70), "\n"))
  cat(glue::glue("🧪 {test_name}\n"))
  cat(glue::glue("   {description}\n"))
  cat(paste0("=", strrep("=", 70), "\n\n"))
}

# Test Footer
print_test_footer <- function(results) {
  passed <- sum(sapply(results, function(x) x$success))
  total <- length(results)
  cat(paste0("=", strrep("=", 70), "\n"))
  cat(glue::glue("📊 RESULTS: {passed}/{total} passed\n"))
  cat(paste0("=", strrep("=", 70), "\n\n"))
}
