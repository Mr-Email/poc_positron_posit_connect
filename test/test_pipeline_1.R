# ============================================================================
# PIPELINE TEST 1: Verify caching & invalidation on input changes
# ============================================================================

source(here::here("test", "_test_helpers.R"))

cat("🧪 PIPELINE TEST 1: Caching & Input-Change Detection\n\n")

results <- list()

# Step 1-2: Generate input & run pipeline
cat("Step 1-2: Initial input & pipeline\n")
source("R/00_generate_dummy_data.R")
targets::tar_make()
output_v1 <- length(list.files("output"))
results[[1]] <- test_result("Initial run", output_v1 == 1, glue::glue("{output_v1} output file"))

# Step 3: Run again (should skip)
cat("\nStep 3: Pipeline skip (no input change)\n")
targets::tar_make()
output_skip <- length(list.files("output"))
# Just check that no new output was created
results[[2]] <- test_result("Skip on no change", output_skip == output_v1, "No new output")

# Step 4: Delete old v002 files & generate new ones
cat("\nStep 4-5: New input & pipeline\n")
old_v002 <- list.files("data/raw", pattern = "_v002\\.csv$", full.names = TRUE)
if (length(old_v002) > 0) unlink(old_v002)

# Generate new v002 files
source("R/00_generate_dummy_data.R")

# Record output count BEFORE
output_before <- length(list.files("output"))

# Run pipeline
targets::tar_make()

# Record output count AFTER - should have new files
output_v2 <- length(list.files("output"))
new_outputs_created <- output_v2 > output_before

results[[3]] <- test_result("Recompute on change", new_outputs_created, glue::glue("{output_v2} total outputs"))

# Step 6: Run again (should skip)
cat("\nStep 6: Pipeline skip (no input change)\n")
targets::tar_make()
output_final <- length(list.files("output"))
results[[4]] <- test_result("Skip stable", output_final == output_v2, "No new output")

# Summary
passed <- sum(sapply(results, function(x) x$success))
cat(glue::glue("\n📊 RESULT: {passed}/4 passed\n\n"))
