---
name: beak-frontend-add-wizard
description: Turn a Beak create or edit flow into validated wizard steps with review and one final submission. Use when a long form should be completed step by step.
---

# Add a wizard

A `BeakWizardScreen` is a `BeakFormScreen` whose steps replace the layout.
Values stay drafts until the final submission.

## Steps

1. Add the screen with ordered steps:

   ```dart
   BeakWizardScreen(
     roles: const {BeakScreenRole.create, BeakScreenRole.edit},
     steps: const [
       BeakWizardStep(title: 'Basics', children: [/* inputs */]),
       BeakWizardStep(title: 'Pricing', children: [/* inputs */]),
     ],
     reviewBeforeSave: true,
   )
   ```

2. A step's children are the same typed inputs as a form. A field belongs to
   one step.
3. `navigation:` chooses inline progress or a rail; `submitLabel:` and
   `reviewBeforeSave:` shape the final action.
4. Model commands on the last step use `submitAction:`.
5. Run `beak prepare`, then the gate.

## Gate

`flutter analyze`, `flutter test`, and the route sweep over the wizard at 375
and 1280 pixels.

## Example prompt

> Use the beak-frontend-add-wizard skill: a three-step product wizard (basics, pricing, review) that saves only at the end.
