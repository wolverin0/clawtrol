// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

// Explicitly register controllers that eagerLoadControllersFrom may miss
// (Propshaft digest cache can cause lazy loading to not find new controllers)
import NotificationsController from "controllers/notifications_controller"
import AutoClaimTagsController from "controllers/auto_claim_tags_controller"
import BoardModalController from "controllers/board_modal_controller"
import CopyUrlController from "controllers/copy_url_controller"
import IconSelectorController from "controllers/icon_selector_controller"
import MobileColumnsController from "controllers/mobile_columns_controller"
import TaskDependenciesController from "controllers/task_dependencies_controller"

application.register("notifications", NotificationsController)
application.register("auto-claim-tags", AutoClaimTagsController)
application.register("board-modal", BoardModalController)
application.register("copy-url", CopyUrlController)
application.register("icon-selector", IconSelectorController)
application.register("mobile-columns", MobileColumnsController)
application.register("task-dependencies", TaskDependenciesController)
