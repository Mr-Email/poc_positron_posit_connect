source("test/_test_helpers.R")

cat("\n")
cat(paste0("🚀 ", strrep("=", 70), "\n"))
cat("RUNNING ALL TESTS\n")
cat(paste0("🚀 ", strrep("=", 70), "\n\n"))

test_setup()

source("test/test_pipeline_1.R")

cat(paste0("=" , strrep("=", 70), "\n"))
