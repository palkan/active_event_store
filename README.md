[![Gem Version](https://badge.fury.io/rb/active_event_store.svg)](https://rubygems.org/gems/active_event_store) [![Build](https://github.com/palkan/active_event_store/workflows/Build/badge.svg)](https://github.com/palkan/active_event_store/actions)

# Active Event Store

Active Event Store is a wrapper over [Rails Event Store](https://railseventstore.org/) which adds conventions and transparent Rails integration.

## Motivation

Why creating a wrapper and not using Rails Event Store itself?

RES is an awesome project but, in our opinion, it lacks Rails simplicity and elegance (=conventions and less boilerplate). It's an advanced tool for advanced developers. We've been using it in multiple projects in a similar way, and decided to extract our approach into this gem (originally private).

Secondly, we wanted to have a store implementation independent API that would allow us to adapterize the actual event store in the future (something like `ActiveEventStore.store_engine = :rails_event_store` or `ActiveEventStore.store_engine = :hanami_events`).

<a href="https://evilmartians.com/?utm_source=active_event_store">
<img src="https://evilmartians.com/badges/sponsored-by-evil-martians.svg" alt="Sponsored by Evil Martians" width="236" height="54"></a>

## Installation

Add the gem to your project:

```ruby
# Gemfile
gem "active_event_store", "~> 1.0"
```

Setup database according to the [Rails Event Store docs](https://railseventstore.org/docs/install/#setup-data-model):

```sh
rails generate rails_event_store_active_record:migration
rails db:migrate
```

### Requirements

- Ruby (MRI) >= 2.6
- Rails >= 6.0
- RailsEventStore >= 2.1

## Usage

### Describe events

Events are represented by _event classes_, which describe events payloads and identifiers:

```ruby
class ProfileCompleted < ActiveEventStore::Event
  # (optional) event identifier is used for transmitting events
  # to subscribers.
  #
  # By default, identifier is equal to `name.underscore.gsub('/', '.')`.
  #
  # You don't need to specify identifier manually, only for backward compatibility when
  # class name is changed.
  self.identifier = "profile_completed"

  # Add attributes accessors
  attributes :user_id

  # Sync attributes only available for sync subscribers
  # (so you can add some optional non-JSON serializable data here)
  # For example, we can also add `user` record to the event to avoid
  # reloading in sync subscribers
  sync_attributes :user
end
```

**NOTE:** we use JSON to [serialize events](https://railseventstore.org/docs/mapping_serialization/), thus only the simple field types (numbers, strings, booleans) are supported.

Each event has predefined (_reserved_) fields:

- `event_id` – unique event id
- `type` – event type (=identifier)
- `metadata`

We suggest to use a naming convention for event classes, for example, using the past tense and describe what happened (e.g. "ProfileCreated", "EventPublished", etc.).

We recommend to keep event definitions in the `app/events` folder.

### Events registration

Since we use _abstract_ identifiers instead of class names, we need a way to tell our _mapper_ how to infer an event class from its type.

In most cases, we register events automatically when they're published or when a subscription is created.

You can also register events manually:

```ruby
# by passing an event class
ActiveEventStore.mapping.register_event MyEventClass

# or more precisely (in that case `event.type` must be equal to "my_event")
ActiveEventStore.mapping.register "my_event", MyEventClass
```

### Publish events

To publish an event you must first create an instance of the event class and call `ActiveEventStore.publish` method:

```ruby
event = ProfileCompleted.new(user_id: user.id)

# or with metadata
event = ProfileCompleted.new(user_id: user.id, metadata: {ip: request.remote_ip})

# then publish the event
ActiveEventStore.publish(event)
```

That's it! Your event has been stored and propagated to the subscribers.

### Subscribe to events

To subscribe a handler to an event you must use `ActiveEventStore.subscribe` method.

You can do this in your app or engine initializer:

```ruby
# some/engine.rb

# To make sure event store has been initialized use the load hook
# `store` == `ActiveEventStore`
ActiveSupport.on_load :active_event_store do |store|
  # async subscriber – invoked from background job, enqueued after the current transaction commits
  # NOTE: all subscribers are asynchronous by default
  store.subscribe MyEventHandler, to: ProfileCreated

  # sync subscriber – invoked right "within" `publish` method
  store.subscribe MyEventHandler, to: ProfileCreated, sync: true

  # anonymous handler (could only be synchronous)
  store.subscribe(to: ProfileCreated, sync: true) do |event|
    # do something
  end

  # you can omit event if your subscriber follows the convention
  # for example, the following subscriber would subscribe to
  # ProfileCreated event
  store.subscribe OnProfileCreated::DoThat
end
```

Subscribers could be any callable Ruby objects that accept a single argument (event) as its input or classes that inherit from `Class` and have `#call` as an instance method.

We suggest putting subscribers to the `app/subscribers` folder using the following convention: `app/subscribers/on_<event_type>/<subscriber.rb>`, e.g. `app/subscribers/on_profile_created/create_chat_user.rb`.

**NOTE:** Active Job must be loaded to use async subscribers (i.e., `require "active_job/railtie"` or `require "rails/all"` in your `config/application.rb`).

**NOTE:** Subscribers that inherit from `Class` and implement `call` as a class method will not be instantiated.

### Testing

You can test subscribers as normal Ruby objects.

**NOTE** To test using minitest include the `ActiveEventStore::TestHelpers` module in your tests.

To test that a given subscriber exists, you can use the `have_enqueued_async_subscriber_for` matcher:

```ruby
# for asynchronous subscriptions (rspec)
it "is subscribed to some event" do
  event = MyEvent.new(some: "data")
  expect { ActiveEventStore.publish event }
    .to have_enqueued_async_subscriber_for(MySubscriberService)
    .with(event)
end

# for asynchronous subscriptions (minitest)
def test_is_subscribed_to_some_event
  event = MyEvent.new(some: "data")

  assert_async_event_subscriber_enqueued(MySubscriberService, event: event) do
    ActiveEventStore.publish event
  end
end
```

**NOTE** Async event subscribers are queued only after the current transaction has committed so when using `assert_enqued_async_subcriber` in rails
make sure to have `self.use_transactional_fixtures = false` at the top of your test class.

**NOTE:** You must have `rspec-rails` gem in your bundle to use `have_enqueued_async_subscriber_for` matcher.

For synchronous subscribers using `have_received` is enough:

```ruby
it "is subscribed to some event" do
  allow(MySubscriberService).to receive(:call)

  event = MyEvent.new(some: "data")

  ActiveEventStore.publish event

  expect(MySubscriberService).to have_received(:call).with(event)
end
```

To test event publishing, use `have_published_event` matcher:

```ruby
# rspec
expect { subject }.to have_published_event(ProfileCreated).with(user_id: user.id)

# minitest
assert_event_published(ProfileCreated, with: {user_id: user.id}) { subject }
```

**NOTE:** `have_published_event` and `assert_event_published` only supports block expectations.

**NOTE 2** `with` modifier works like `have_attributes` matcher (not `contain_exactly`); you can only specify serializable attributes in `with` (i.e. sync attributes are not supported, 'cause they are not persistent).

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/palkan/active_event_store](https://github.com/palkan/active_event_store).

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
