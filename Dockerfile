FROM ruby:3.4.1

COPY summary.rb /

ENTRYPOINT ["/summary.rb"]
