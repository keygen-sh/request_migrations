module RequestMigrations
  class Railtie < ::Rails::Railtie
    ActionDispatch::Routing::Mapper.send(:include, Router::Constraints)
  end
end
