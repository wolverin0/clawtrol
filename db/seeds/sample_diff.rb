# Sample diff data for testing the diff viewer
# Run with: bin/rails runner db/seeds/sample_diff.rb

SAMPLE_DIFF_CONTENT = <<~DIFF
diff --git a/app/models/user.rb b/app/models/user.rb
index 1234567..abcdefg 100644
--- a/app/models/user.rb
+++ b/app/models/user.rb
@@ -1,15 +1,22 @@
 class User < ApplicationRecord
   has_many :tasks
   has_many :boards, through: :tasks
+  has_many :notifications
+  has_many :preferences
 
   validates :email, presence: true, uniqueness: true
   validates :name, presence: true
+  validates :role, inclusion: { in: %w[admin member viewer] }
 
-  def full_name
-    "\#{first_name} \#{last_name}"
+  # Enhanced full name with optional title
+  def full_name(include_title: false)
+    base = "\#{first_name} \#{last_name}"
+    include_title && title.present? ? "\#{title} \#{base}" : base
   end
 
   def admin?
-    role == "admin"
+    role.to_s == "admin"
+  end
+
+  def active_notifications
+    notifications.where(read: false).order(created_at: :desc)
   end
 end
DIFF

SAMPLE_JS_DIFF = <<~DIFF
diff --git a/app/javascript/controllers/task_modal_controller.js b/app/javascript/controllers/task_modal_controller.js
index 9876543..fedcba9 100644
--- a/app/javascript/controllers/task_modal_controller.js
+++ b/app/javascript/controllers/task_modal_controller.js
@@ -5,8 +5,12 @@ export default class extends Controller {
   static targets = [
     "backdrop",
     "modal",
-    "form"
+    "form",
+    "nameField",
+    "descriptionField",
+    "priorityField"
   ]
 
   static values = {
     taskId: Number,
+    autoSaveDelay: { type: Number, default: 1000 }
   }
@@ -15,6 +19,10 @@ export default class extends Controller {
   connect() {
     this._handleEscape = this._handleEscape.bind(this)
     document.addEventListener("keydown", this._handleEscape)
+
+    // Initialize auto-save timer
+    this._autoSaveTimer = null
+    this._pendingChanges = false
   }
 
   disconnect() {
@@ -22,6 +30,22 @@ export default class extends Controller {
     document.removeEventListener("keydown", this._handleEscape)
   }
 
+  scheduleAutoSave() {
+    this._pendingChanges = true
+    
+    if (this._autoSaveTimer) {
+      clearTimeout(this._autoSaveTimer)
+    }
+
+    this._autoSaveTimer = setTimeout(() => {
+      this._performAutoSave()
+    }, this.autoSaveDelayValue)
+  }
+
+  _performAutoSave() {
+    if (!this._pendingChanges) return
+    this._pendingChanges = false
+    this.formTarget.requestSubmit()
+  }
+
   open() {
     this.backdropTarget.classList.remove("hidden")
     this.modalTarget.classList.remove("hidden")
DIFF

SAMPLE_CSS_DIFF = <<~DIFF
diff --git a/app/assets/stylesheets/application.css b/app/assets/stylesheets/application.css
index abcdef1..1234567 100644
--- a/app/assets/stylesheets/application.css
+++ b/app/assets/stylesheets/application.css
@@ -12,6 +12,18 @@
 .scrollbar-hide::-webkit-scrollbar { display: none; }
 .scrollbar-hide { -ms-overflow-style: none; scrollbar-width: none; }
 
+/* Diff viewer enhancements */
+.diff-viewer-enhanced .d2h-wrapper {
+  border-radius: 0.75rem;
+  overflow: hidden;
+}
+
+.diff-viewer-enhanced .d2h-file-header:hover {
+  background: rgba(255, 255, 255, 0.03);
+}
+
+.diff-viewer-enhanced .d2h-code-line-ctn {
+  tab-size: 4;
+}
+
 /* Filter hidden tasks */
 .filter-hidden {
   display: none !important;
DIFF

# Find a task to attach diffs to, or create one
board = Board.first
unless board
  puts "No boards found. Create a board first."
  exit
end

task = board.tasks.where(status: %w[in_review done]).first
unless task
  task = board.tasks.first
end

unless task
  puts "No tasks found. Create a task first."
  exit
end

puts "Attaching sample diffs to task ##{task.id}: #{task.name}"

# Create sample diffs
[
  { file_path: "app/models/user.rb", diff_type: "modified", diff_content: SAMPLE_DIFF_CONTENT },
  { file_path: "app/javascript/controllers/task_modal_controller.js", diff_type: "modified", diff_content: SAMPLE_JS_DIFF },
  { file_path: "app/assets/stylesheets/application.css", diff_type: "modified", diff_content: SAMPLE_CSS_DIFF }
].each do |attrs|
  diff = task.task_diffs.find_or_initialize_by(file_path: attrs[:file_path])
  diff.assign_attributes(attrs)
  diff.save!
  puts "  ✅ #{attrs[:diff_type]} #{attrs[:file_path]} (#{diff.stats[:additions]}+/#{diff.stats[:deletions]}-)"
end

# Also set output_files if not already set
if task.output_files.blank? || task.output_files.empty?
  task.update(output_files: ["app/models/user.rb", "app/javascript/controllers/task_modal_controller.js", "app/assets/stylesheets/application.css"])
  puts "  📁 Set output_files on task"
end

puts "\n✨ Done! Visit the task detail panel for task ##{task.id} to see the diff viewer."
puts "   URL: /boards/#{board.id}/tasks/#{task.id}"
