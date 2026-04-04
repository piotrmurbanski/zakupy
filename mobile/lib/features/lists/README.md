# Lists feature

Current mobile flow:
- list overview page that loads `/lists` and supports pull-to-refresh
- create-list action from the authenticated home screen
- list detail page with item list, add, edit, delete, and check-off actions
- share-list action by email from the detail screen
- rename-list action from the detail screen for list owners
- optimistic updates with reconciliation after server writes
- periodic refresh in the detail view to catch changes from the other user

Backend capabilities that already exist but are not fully exposed in the mobile UI yet:
- deleting a list
- removing list members
