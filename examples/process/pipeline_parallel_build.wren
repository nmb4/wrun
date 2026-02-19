// Example: Parallel build tasks (lint, test, typecheck) then deploy
import "wrun/pipeline" for Pipeline
import "wrun/print" for Log

Log.info("Running parallel build pipeline")

Pipeline.new()
  .task("lint", "sleep 1 && echo 'Linting passed'")
  .task("test", "sleep 2 && echo 'Tests passed'")
  .task("typecheck", "sleep 1.5 && echo 'Types OK'")
  .afterAll(["lint", "test", "typecheck"], "build", "sleep 1 && echo 'Build complete'")
  .after("build", "deploy", "sleep 1 && echo 'Deployed!'")
  .run()
