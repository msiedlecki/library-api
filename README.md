# Library API

The API runs on Rails 8.1 with PostgreSQL and Solid Queue.

## Setup

Start the development stack from the repository root:

```sh
docker compose up --build
```
The Compose `web` service runs in development mode on port 3000 and connects to the PostgreSQL `db` service. At startup, it runs `bin/rails db:prepare` to prepare the database; Rails seeds it when it is first created.

## API and Swagger UI

The API is available at <http://localhost:3000>, with Swagger UI at <http://localhost:3000/api-docs>. The documentation covers the `/books` endpoints with response details and examples.

## Design decisions

- Soft deletion through `discarded_at` preserves the loan history for each physical copy.
- Book status is derived rather than stored in a column. A book with an active loan is `borrowed`; otherwise, an active book is `available`. This keeps loan data as the single source of truth for status.
- Borrowing and returning are domain actions, not generic `PATCH` updates. Borrowing creates a loan and requires a reader; returning sets the loan's `returned_at` timestamp. A default update action would not express these operations as clearly.
- Readers are resolved during borrowing. A reader is created automatically when the card number is new. If it already exists, both the name and email must match.
- At this scale, the rules fit in the models without introducing service objects. Serializers and a shared error-handling concern keep the controllers focused.
- The reminder job selects active loans due today or in three days and queues email with `deliver_later`. The mailer uses the `:test` adapter, and the daily schedule in `config/recurring.yml` runs the job at 8 a.m.
- The Gemfile uses the Rails/PostgreSQL stack, with RSpec, Factory Bot, Faker, and rswag included for development and testing.
- Database constraints provide an additional layer of protection, including when writes bypass model validations.

## Limitations and future work

- There is no authentication.
- There is no reader CRUD API.
- The job does not send reminders for overdue loans, so a missed daily run is not caught up later.
- After a reminder is queued, the app records a timestamp. If delivery later fails, that timestamp may prevent a retry.

Beyond production configuration, possible future improvements include authentication, reader endpoints, loan extensions, overdue reminders, job monitoring, and service objects if the domain becomes more complex.
