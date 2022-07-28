# request_migrations

[![Gem Version](https://badge.fury.io/rb/request_migrations.svg)](https://badge.fury.io/rb/request_migrations)

**Make breaking API changes without breaking things!** Use `request_migrations` to craft
backwards-compatible migrations for API requests, responses, and more. Read [the blog
post](https://keygen.sh/blog/breaking-things-without-breaking-things/).

This gem was extracted from [Keygen](https://keygen.sh) and is being used in production
to serve millions of API requests per day.

![request_migrations diagram](https://user-images.githubusercontent.com/6979737/175964358-a2d8951d-46c6-4962-9f5e-0569cbf5972e.png)

Sponsored by:

[![Keygen logo](https://user-images.githubusercontent.com/6979737/175406169-bd8bf064-7343-4bd1-94b7-a773ecec07b8.png)](https://keygen.sh)

_A software licensing and distribution API built for developers._

Links:

- [Installing request_migrations](#installation)
- [Supported Ruby versions](#supported-rubies)
- [RubyDoc](#documentation)
- [Usage](#usage)
  - [Response migrations](#response-migrations)
  - [Request migrations](#request-migrations)
  - [Data migrations](#data-migrations)
  - [Routing constraints](#routing-constraints)
  - [Configuration](#configuration)
  - [Version formats](#version-formats)
- [Testing](#testing)
- [Tips and tricks](#tips-and-tricks)
- [Credits](#credits)
- [Contributing](#contributing)
- [License](#license)

## Installation

Add this line to your application's `Gemfile`:

```ruby
gem 'request_migrations'
```

And then execute:

```bash
$ bundle
```

Or install it yourself as:

```bash
$ gem install request_migrations
```

## Supported Rubies

`request_migrations` supports Ruby 3. We encourage you to upgrade if you're on an older
version. Ruby 3 provides a lot of great features, like better pattern matching.

## Documentation

You can find the documentation on [RubyDoc](https://rubydoc.info/github/keygen-sh/request_migrations).

_We're working on improving the docs._

## Features

- Define migrations for migrating a response between versions.
- Define migrations for migrating a request between versions.
- Define migrations for applying data migrations.
- Define version-based routing constraints.
- It's fast.

## Usage

Use `request_migrations` to make _backwards-incompatible_ changes in your code, while
providing a _backwards-compatible_ interface for clients on older API versions. What
exactly does that mean? Well, let's demonstrate!

Let's assume that we provide an API service, which has `/users` CRUD resources.

Let's also assume we start with the following `User` model:

```ruby
class User
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
end
```

After awhile, we realize our `User` model's combined `name` attribute is not working too
well, and we want to change it to `first_name` and `last_name`.

So we write a database migration that changes our `User` model:

```ruby
class User
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :first_name, :string
  attribute :last_name, :string
end
```

But what about the API consumers who were relying on `name`? We just broke our API contract
with them! To resolve this, let's create our first request migration.

We recommend that migrations be stored under `app/migrations/`.

```ruby
class CombineNamesForUserMigration < RequestMigrations::Migration
  # Provide a useful description of the change
  description %(transforms a user's first and last name to a combined name attribute)

  # Migrate inputs that contain a user. The migration should mutate
  # the input, whatever that may be.
  migrate if: -> data { data in type: 'user' } do |data|
    first_name = data.delete(:first_name)
    last_name  = data.delete(:last_name)

    data[:name] = "#{first_name} #{last_name}"
  end

  # Migrate the response. This is where you provide the migration input.
  response if: -> res { res.successful? && res.request.params in controller: 'api/v1/users',
                                                                 action: 'show' } do |res|
    data = JSON.parse(res.body, symbolize_names: true)

    # Call our migrate definition above
    migrate!(data)

    res.body = JSON.generate(data)
  end
end
```

As you can see, with pattern matching, it makes creating migrations for certain
resources simple. Here, we've defined a migration that only runs for the `users#show`
resource, and only when the response is successfuly. In addition, the data is
only migrated when the response body contains a user.

Next, we'll need to configure `request_migrations` via an initializer under
`initializers/request_migrations.rb`:

```ruby
RequestMigrations.configure do |config|
  # Define a resolver to determine the target version. Here, you can perform
  # a lookup on the current user using request parameters, or simply use
  # a header like we are here, defaulting to the latest version.
  config.request_version_resolver = -> request {
    request.headers.fetch('Foo-Version') { config.current_version }
  }

  # Define the latest version of our application.
  config.current_version = '1.1'

  # Define previous versions and their migrations, in descending order.
  config.versions = {
    '1.0' => %i[combine_names_for_user_migration],
  }
end
```

Lastly, you'll want to update your application controller so that migrations
are applied:

```ruby
class ApplicationController < ActionController::API
  include RequestMigrations::Controller::Migrations

  # Optionally rescue from requests for unsupported versions
  rescue_from RequestMigrations::UnsupportedVersionError, with: -> {
    render(
      json: { error: 'unsupported API version requested', code: 'INVALID_API_VERSION' },
      status: :bad_request,
    )
  }
end
```

Now, when an API client provides a `Foo-Version: 1.0` header, they'll receive a
response containing the combined `name` attribute.

### Response migrations

We covered this above, but response migrations define a change to a response.
You define a response migration by using the `response` class method.

```ruby
class RemoveVowelsMigration < RequestMigrations::Migration
  description %(in the past, we had a bug that removed all vowels, and some clients rely on that behavior)

  response if: -> res { res.request.params in action: 'index' | 'show' | 'create' | 'update' } do |res|
    body = JSON.parse(res.body, symbolize_names: true)

    # Mutate the response body by removing all vowels
    body.deep_transform_values! { _1.gsub(/[aeiou]/, '') }

    res.body = JSON.generate(body)
  end
end
```

The `response` method accepts an `:if` keyword, which should be a lambda
that evaluates to a boolean, which determines whether or not the migration
should be applied. An `ActionDispatch::Response` will be yielded, the
current response (calls `controller#response`).

The gem makes no assumption on a response's content type or what the migration
will do. You could, for example, migrate the response body, or mutate the
headers, or even change the response's status code.

### Request migrations

Request migrations define a change on a request. For example, modifying a request's
headers. You define a response migration by using the `request` class method.

```ruby
class AssumeContentTypeMigration < RequestMigrations::Migration
  description %(in the past, we assumed all requests were JSON, but that has since changed)

  # Migrate the request, adding an assumed content type to all requests.
  request do |req|
    req.headers['Content-Type'] = 'application/json'
  end
end
```

The `request` method accepts an `:if` keyword, which should be a lambda
that evaluates to a boolean, which determines whether or not the migration
should be applied. An `ActionDispatch::Request` object will be yielded,
the current request (calls `controller#request`).

Again, like with response migrations, the gem makes no assumption on what
a migration does. A migration could mutate a request's params, or mutate
headers. It's up to you, all it does is provide the request.

Request migrations should [avoid using the `migrate` method](#avoid-migrate-for-request-migrations).

### Data migrations

In our first scenario, where we combined our user's name attributes, we defined
our migration using the `migrate` class method. At this point, you may be wondering
why we did that, since we didn't use that method for the 2 previous request and
response migrations above.

Well, it comes down to support for data migrations (as well as offering a nice
interface for pattern matching inputs). Let's go back to our first example,
`CombineNamesForUserMigration`.

```ruby
class CombineNamesForUserMigration < RequestMigrations::Migration
  # Provide a useful description of the change
  description %(transforms a user's first and last name to a combined name attribute)

  # Migrate inputs that contain a user. The migration should mutate
  # the input, whatever that may be.
  migrate if: -> data { data in type: 'user' } do |data|
    first_name = data.delete(:first_name)
    last_name  = data.delete(:last_name)

    data[:name] = "#{first_name} #{last_name}"
  end

  # Migrate the response. This is where you provide the migration input.
  response if: -> res { res.successful? && res.request.params in controller: 'api/v1/users' | 'api/v1/me',
                                                                 action: 'show' } do |res|
    data = JSON.parse(res.body, symbolize_names: true)

    # Call our migrate definition above
    migrate!(data)

    res.body = JSON.generate(data)
  end
end
```

What if we had [a webhook system](https://keygen.sh/blog/how-to-build-a-webhook-system-in-rails-using-sidekiq/)
that we also needed to apply these migrations to? Well, we can use a data migration
here, via the `Migrator` class:

```ruby
class WebhookWorker
  def perform(event, endpoint, data)
    # ...

    # Migrate event data from latest version to endpoint's configured version
    current_version = RequestMigrations.config.current_version
    target_version  = endpoint.api_version
    migrator        = RequestMigrations::Migrator.new(
      from: current_version,
      to: target_version,
    )

    # Migrate the event data (tries to apply all matching migrations)
    migrator.migrate!(data:)

    # ...

    event.send!(data)
  end
end
```

This will apply the block defined in `migrate` onto our data. With that,
we've successfully applied a migration to both our API responses, as well
as to the webhook events we send. In this case, if our `event` matches the
our user shape, e.g. `type: 'user'`, then the migration will be applied.

In addition to data migrations, this allows for easier testing.

### Routing constraints

When you want to encourage API clients to upgrade, you can utilize a routing `version_constraint`
to define routes only available for certain versions.

You can also utilize routing constraints to remove an API endpoint entirely.

```ruby
Rails.application.routes.draw do
  # This endpoint is only available for version 1.1 and above
  version_constraint '>= 1.1' do
    resources :some_shiny_new_resource
  end

  # Remove this endpoint for any version below 1.1
  version_constraint '< 1.1' do
    scope module: :v1x0 do
      resources :a_deprecated_resource
    end
  end
end
```

Currently, routing constraints only work for the `:semver` version format. (PRs welcome!)

### Configuration

```ruby
RequestMigrations.configure do |config|
  # Define a resolver to determine the target version. Here, you can perform
  # a lookup on the current user using request parameters, or simply use
  # a header like we are here, defaulting to the latest version.
  config.request_version_resolver = -> request {
    request.headers.fetch('Foo-Version') { config.current_version }
  }

  # Define the accepted version format. Default is :semver.
  config.version_format = :semver

  # Define the latest version of our application.
  config.current_version = '1.2'

  # Define previous versions and their migrations, in descending order.
  # Should be a hash, where the key is the version and the value is an
  # array of migration symbols or classes.
  config.versions = {
    '1.1' => %i[
      has_one_author_to_has_many_for_posts_migration
      has_one_author_to_has_many_for_post_migration
    ],
    '1.0' => %i[
      combine_names_for_users_migration
      combine_names_for_user_migration
    ],
  }

  # Use a custom logger. Supports ActiveSupport::TaggedLogging.
  config.logger = Rails.logger
end
```

### Version formats

By default, `request_migrations` uses a `:semver` version format, but it can be configured
to instead use one of the following, set via `config.version_format=`.

| Format     |                                                      |
|:-----------|:-----------------------------------------------------|
| `:semver`  | Use semantic versions, e.g. `1.0`, `1.1`, and `2.0`. |
| `:date`    | Use date versions, e.g. `2020-09-02`, `2021-01-01`.  |
| `:integer` | Use integer versions, e.g. `1`, `2`, and `3`.        |
| `:float`   | Use float versions, e.g. `1.0`, `1.1`, and `2.0`.    |
| `:string`  | Use string versions, e.g. `a`, `b`, and `z`.         |

All versions will be sorted according to the format's type.

## Testing

Using data migrations allows for easier testing of migrations. For example, using Rspec:

```ruby
describe CombineNamesForUserMigration do
  before do
    RequestMigrations.configure do |config|
      config.current_version = '1.1'
      config.versions        = {
        '1.0' => [CombineNamesForUserMigration],
      }
    end
  end

  it 'should migrate user name attributes' do
    migrator = RequestMigrations::Migrator.new(from: '1.1', to: '1.0')
    data     = serialize(
      create(:user, first_name: 'John', last_name: 'Doe'),
    )

    expect(data).to include(type: 'user', first_name: 'John', last_name: 'Doe')
    expect(data).to_not include(name: anything)

    migrator.migrate!(data:)

    expect(data).to include(type: 'user', name: 'John Doe')
    expect(data).to_not include(first_name: 'John', last_name: 'Doe')
  end
end
```

To avoid polluting the global configuration, you can use `RequestMigrations::Testing`
within your application's `spec/rails_helper.rb` (or similar).

```ruby
require 'request_migrations/testing'

Rspec.configure do |config|
  config.before :each do
    RequestMigrations::Testing.setup!
  end

  config.after :each do
    RequestMigrations::Testing.teardown!
  end
end
```

## Tips and tricks

Over the years, we're learned a thing or two about versioning an API. We'll share tips here.

### Use pattern matching

Pattern matching really cleans up the `:if` conditions, and overall makes migrations more readable.

```ruby
class AddUsernameAttributeToUsersMigration < RequestMigrations::Migration
  description %(adds username attributes to a collection of users)

  migrate if: -> body { body in data: [*] } do |body|
    case body
    in data: [*, { type: 'users', attributes: { ** } }, *]
      body[:data].each do |user|
        case user
        in type: 'users', attributes: { email: }
          user[:attributes][:username] = email
        else
        end
      end
    else
    end
  end

  response if: -> res { res.successful? && res.request.params in controller: 'api/v1/users',
                                                                 action: 'index' } do |res|
    body = JSON.parse(res.body, symbolize_names: true)

    migrate!(body)

    res.body = JSON.generate(body)
  end
end
```

Just be sure to remember your `else` block when `case` pattern matching. :)

### Route helpers

If you need to use route helpers in a migration, include them in your migration:

```ruby
class SomeMigration < RequestMigrations::Migration
  include Rails.application.routes.url_helpers
end
```

### Separate by shape

Define separate migrations for different input shapes, e.g. define a migration for an `#index`
to migrate an array of objects, and define another migration that handles the singular object
from `#show`, `#create` and `#update`. This will help keep your migrations readable.

For example, for a singular user response:

```ruby
class CombineNamesForUserMigration < RequestMigrations::Migration
  description %(transforms a user's first and last name to a combined name attribute)

  migrate if: -> data { data in type: 'user' } do |data|
    first_name = data.delete(:first_name)
    last_name  = data.delete(:last_name)

    data[:name] = "#{first_name} #{last_name}"
  end

  response if: -> res { res.successful? && res.request.params in controller: 'api/v1/users',
                                                                 action: 'show' } do |res|
    data = JSON.parse(res.body, symbolize_names: true)

    migrate!(data)

    res.body = JSON.generate(data)
  end
end
```

And for a response containing a collection of users:

```ruby
class CombineNamesForUserMigration < RequestMigrations::Migration
  description %(transforms a collection of users' first and last names to a combined name attribute)

  migrate if: -> data { data in [*, { type: 'user' }, *] do |data|
    data.each do |record|
      case record
      in type: 'user', first_name:, last_name:
        record[:name] = "#{first_name} #{last_name}"

        record.delete(:first_name)
        record.delete(:last_name)
      else
      end
    end
  end

  response if: -> res { res.successful? && res.request.params in controller: 'api/v1/users',
                                                                 action: 'index' } do |res|
    data = JSON.parse(res.body, symbolize_names: true)

    migrate!(data)

    res.body = JSON.generate(data)
  end
end
```

Note that the `migrate` method now migrates an array input, and matches on the `#index` route.

### Always check response status

Always check a response's status. You don't want to unintentionally apply migrations to error
responses.

```ruby
class SomeMigration < RequestMigrations::Migration
  response if: -> res { res.successful? } do |res|
    # ...
  end
end
```

Also mind `204 No Content`, since the response body will be `nil`.

### Don't match on URL pattern

Don't match on URL pattern. Instead, use `response.request.params` to access the request params
in a `response` migration, and use the `:controller` and `:action` params to determine route.

```ruby
class SomeMigration < RequestMigrations::Migration
  # Bad
  response if: -> res { res.request.path.matches?(/^\/v1\/posts$/) }

  # Good
  response if: -> res { res.request.params in controller: 'api/v1/posts', action: 'index' }
end
```

### Namespace deprecated controllers

When you need to entirely change a controller or service class, use a `V1x0::UsersController`-style
namespace to keep the old deprecated classes tidy.

```ruby
class V1x0::UsersController
  def foo
    # Some old foo action
  end
end
```

### Avoid migrate for request migrations

Avoid using `migrate` for request migrations. If you do, then data migrations, e.g. for
webhooks, will attempt to apply the request migrations. This may erroneously produce bad
output, or even undo a response migration. Instead, keep all request migration logic,
e.g. transforming params, inside of the `request` block.

```ruby
class SomeMigration < RequestMigrations::Migration
  # Bad (side-effects for data migrations)
  migrate do |params|
    params[:foo] = params.delete(:bar)
  end

  request do |req|
    migrate!(req.params)
  end

  # Good
  request do |req|
    req.params[:foo] = req.params.delete(:bar)
  end
end
```

### Avoid routing contraints

Avoid using routing version constraints that remove functionality. They can be a headache
during upgrades. Consider only making _additive_ changes. Instead, consider removing or
hiding the documenation for old or deprecated endpoints, to limit any new usage.

```ruby
Rails.application.routes.draw do
  resources :users do
    # Iffy
    version_constraint '< 1.1' do
      resources :posts
    end

    # Good
    scope module: :v1x0 do
      resources :posts
    end
  end
end
```

### Avoid n+1s

Avoid introducing n+1 queries in your migrations. Try to utilize the current data you have
to perform more meaningful queries, returning only the data needed for the migration.

```ruby
class AddRecentPostToUsersMigration < RequestMigrations::Migration
  description %(adds :recent_post association to a collection of users)

  # Bad (n+1)
  migrate if: -> data { data in [*, { type: 'user' }, *] do |data|
    data.each do |record|
      case record
      in type: 'user', id:
        recent_post = Post.reorder(created_at: :desc)
                          .find_by(user_id: id)

        record[:recent_post] = recent_post&.id
      else
      end
    end
  end

  # Good
  migrate if: -> data { data in [*, { type: 'user' }, *] do |data|
    user_ids = data.collect { _1[:id] }
    post_ids = Post.select(:id, :user_id)
                   .distinct_on(:user_id)
                   .where(user_id: user_ids)
                   .reorder(created_at: :desc)
                   .group_by(&:user_id)

    data.each do |record|
      case record
      in type: 'user', id: user_id
        record[:recent_post] = post_ids[user_id]&.id
      else
      end
    end
  end

  response if: -> res { res.successful? && res.request.params in controller: 'api/v1/users',
                                                                 action: 'index' } do |res|
    data = JSON.parse(res.body, symbolize_names: true)

    migrate!(data)

    res.body = JSON.generate(data)
  end
end
```

Instead of potentially tens or hundreds of queries, we make a single purposeful query
to get the data we need in order to complete the migration.

---

Have a tip of your own? Open a pull request!

## Is it any good?

Yes.

## Credits

Credit goes to Stripe for inspiring the [high-level migration strategy](https://stripe.com/blog/api-versioning).
Intercom has [another good post on the topic](https://www.intercom.com/blog/api-versioning/).

## Contributing

If you have an idea, or have discovered a bug, please open an issue or create a pull request.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
