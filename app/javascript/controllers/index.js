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
import AgentChatController from "controllers/agent_chat_controller"
import AgentActivityController from "controllers/agent_activity_controller"
import AgentTerminalController from "controllers/agent_terminal_controller"
import AgentModalController from "controllers/agent_modal_controller"
import AgentPreviewController from "controllers/agent_preview_controller"
import OpenclawMemoryIndicatorController from "controllers/openclaw_memory_indicator_controller"
import EvidenceTabsController from "controllers/evidence_tabs_controller"
import CollapsibleController from "controllers/collapsible_controller"
import MarketingTreeController from "controllers/marketing_tree_controller"
import ShowcaseTabsController from "controllers/showcase_tabs_controller"
import MobileNavController from "controllers/mobile_nav_controller"
import NightshiftController from "controllers/nightshift_controller"
import FactoryController from "controllers/factory_controller"
import SwarmRefreshController from "controllers/swarm_refresh_controller"
import CommandController from "controllers/command_controller"
import WorkflowEditorController from "controllers/workflow_editor_controller"
import CronjobsController from "controllers/cronjobs_controller"
import TokensController from "controllers/tokens_controller"
import CostAnalyticsController from "controllers/cost_analytics_controller"
import GatewayHealthController from "controllers/gateway_health_controller"
import WebTerminalController from "controllers/web_terminal_controller"
import DashboardRefreshController from "controllers/dashboard_refresh_controller"
import CommandPaletteController from "controllers/command_palette_controller"
import InlineEditController from "controllers/inline_edit_controller"

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
application.register("agent-chat", AgentChatController)
application.register("agent-activity", AgentActivityController)
application.register("agent-terminal", AgentTerminalController)
application.register("agent-modal", AgentModalController)
application.register("agent-preview", AgentPreviewController)
application.register("openclaw-memory-indicator", OpenclawMemoryIndicatorController)
application.register("evidence-tabs", EvidenceTabsController)
application.register("collapsible", CollapsibleController)
application.register("marketing-tree", MarketingTreeController)
application.register("showcase-tabs", ShowcaseTabsController)
application.register("mobile-nav", MobileNavController)
application.register("nightshift", NightshiftController)
application.register("factory", FactoryController)
application.register("swarm-refresh", SwarmRefreshController)
application.register("command", CommandController)
application.register("workflow-editor", WorkflowEditorController)
application.register("cronjobs", CronjobsController)
application.register("tokens", TokensController)
application.register("cost-analytics", CostAnalyticsController)
application.register("gateway-health", GatewayHealthController)
application.register("web-terminal", WebTerminalController)
application.register("dashboard-refresh", DashboardRefreshController)
application.register("command-palette", CommandPaletteController)
application.register("inline-edit", InlineEditController)

import ThemeToggleController from "controllers/theme_toggle_controller"
application.register("theme-toggle", ThemeToggleController)
