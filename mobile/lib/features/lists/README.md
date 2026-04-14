# Lists feature

Current mobile flow:
- list overview page that loads `/lists` and supports pull-to-refresh
- create-list action from the authenticated home screen
- list detail page with item list, add, edit, delete, and check-off actions
- item rows support quick quantity increments on tap and a visible edit action plus category icon
- item editor supports a broader set of category icons inspired by the shopping categories in the app and defaults new items to the generic "Inne" option
- product suggestions keep the last chosen category icon, so repeating the same product reuses the right icon automatically
- share-list action by email from the detail screen
- rename-list action from the detail screen for list owners
- optimistic updates with reconciliation after server writes
- periodic refresh in the detail view to catch changes from the other user

Backend capabilities that already exist but are not fully exposed in the mobile UI yet:
- deleting a list
- removing list members
