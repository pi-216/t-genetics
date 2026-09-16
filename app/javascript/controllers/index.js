import { application } from "controllers/application"
import AlleleTypeFieldsController from "controllers/allele_type_fields_controller"
import ClipboardCopyController from "controllers/clipboard_copy_controller"

application.register("allele-type-fields", AlleleTypeFieldsController)
application.register("clipboard-copy", ClipboardCopyController)