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
import SearchController from "controllers/search_controller"
import FilterController from "controllers/filter_controller"
import BulkOperationsController from "controllers/bulk_operations_controller"
import WizardController from "controllers/wizard_controller"
import DragAssignController from "controllers/drag_assign_controller"
import SoundController from "controllers/sound_controller"
import SoundToggleController from "controllers/sound_toggle_controller"
import AgentCategoriesController from "controllers/agent_categories_controller"
import MobileFilterController from "controllers/mobile_filter_controller"

application.register("notifications", NotificationsController)
application.register("auto-claim-tags", AutoClaimTagsController)
application.register("board-modal", BoardModalController)
application.register("copy-url", CopyUrlController)
application.register("icon-selector", IconSelectorController)
application.register("mobile-columns", MobileColumnsController)
application.register("task-dependencies", TaskDependenciesController)
application.register("search", SearchController)
application.register("filter", FilterController)
application.register("bulk-operations", BulkOperationsController)
application.register("wizard", WizardController)
application.register("drag-assign", DragAssignController)
application.register("sound", SoundController)
application.register("sound-toggle", SoundToggleController)
application.register("agent-categories", AgentCategoriesController)
application.register("mobile-filter", MobileFilterController)
