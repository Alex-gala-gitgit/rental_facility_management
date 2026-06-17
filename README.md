# Rental Facility Manager

A Flutter prototype for a rental management app with two roles:

- Owner: create facilities, monitor rent/utilities, approve tenant payment slips, and view dashboard reports.
- Tenant: view monthly bill, submit payment proof, and track approval status.

This first version uses local in-memory sample data so you can test the app flow before connecting Firebase.

## Run

```powershell
cd C:\Users\User\Documents\Codex\2026-06-16\i-m-new-to-github\rental_facility_manager
flutter pub get
flutter run
```

If platform folders are missing because `flutter create` did not finish, run this inside the project folder:

```powershell
flutter create .
flutter run
```

## Next Backend Step

For production, connect:

- Firebase Authentication for owner/tenant login
- Cloud Firestore for facilities, tenancies, bills, payments, and expenses
- Firebase Storage for payment slip images/PDFs
- Firebase Cloud Messaging for push notifications
- Cloud Functions for monthly bill generation and reminders
