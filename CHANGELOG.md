# Change log

## master

## 1.2.0 (2024-01-25)

- Use custom pipeline mapper and domain event transformer. ([@Samsinite][])

## 1.1.0 (2023-08-24)

- Require Ruby 2.7+. ([@palkan][])

- Fix compatibility with RES 2.11 ([@palkan][])

## 1.0.2 (2021-03-15)

- Support using classes with `#call` as async subscribers. ([@caws][])

## 1.0.1 (2021-09-16)

- Add minitest assertions: `assert_event_published`, `refute_event_published`, `assert_async_event_subscriber_enqueued`  ([@chriscz][])

## 1.0.0 (2021-09-14)

- Ruby 2.6+, Rails 6+ and RailsEventStore 2.1+ is required.

## 0.2.1 (2020-09-30)

- Fix Active Support load hook name. ([@palkan][])

Now `ActiveSupport.on_load(:active_event_store) { ... }` works.

## 0.2.0 (2020-05-11)

- Update Event API to support both RES 1.0 and 0.42+. ([@palkan][])

## 0.1.0 (2020-04-22)

- Open source Active Event Store. ([@palkan][])

[@palkan]: https://github.com/palkan
[@chriscz]: https://github.com/chriscz
[@caws]: https://github.com/caws
[@Samsinite]: https://github.com/Samsinite
