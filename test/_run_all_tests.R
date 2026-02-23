source("test/_test_helpers.R")

cat("\n")
cat(paste0("🚀 ", strrep("=", 70), "\n"))
cat("RUNNING ALL TESTS\n")
cat(paste0("🚀 ", strrep("=", 70), "\n\n"))

# ============================================================================
# CLEAN SLATE: Lösche alten Cache für stabilitäts-Tests
# ============================================================================

cat("🧹 Räume auf: Lösche alten targets Cache...\n")
library(targets)
if (dir.exists("_targets")) {
  unlink("_targets", recursive = TRUE)
  cat("   ✅ Cache gelöscht\n")
} else {
  cat("   ℹ️  Cache war bereits leer\n")
}

cat("\n")

test_setup()

source("test/test_pipeline_1.R")

cat(paste0("=", strrep("=", 70), "\n"))
