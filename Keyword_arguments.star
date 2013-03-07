Here's the long awaited last post in the "Ruby 2.0 feature's tour" series. With a release date still fixed to the 24th of February, it was about time.

This post's topic will be about "Keyword arguments". As you can see, Keyword arguments is not really a new feature invented by the Ruby designers, but rather an addition that has been available for years in others languages..

Principle
Keyword arguments gives the possibility to define arguments in a flexible way. The common practice is to use Hash to pass several arguments in any order.

def devblog(title, options = {})
  puts title, options[:tags], options.fetch(:layout, "post")
end

devblog "Ruby 2.0 : Keyword arguments", tags: ['ruby']
# => "Ruby 2.0 : Keyword arguments"
# => ['ruby']
# => "post"
The same feature could be achieved by using Keyword arguments:

def devblog(title, layout: "post", tags: [])
  puts title, tags, layout
end

devblog "Ruby 2.0 : Keyword arguments", tags: ['ruby']
# => "Ruby 2.0 : Keyword arguments"
# => ['ruby']
# => "post"
No extra fetch for default values, and arguments available as local variable.

In the above example, title is not specified as a Keyword argument to mark this argument as mandatory.

Well, it could be done using Keyword arguments but it's kind of weird.

def devblog(title: raise(ArgumentError), layout: "post", tags: [])
  puts title, tags, layout
end

devblog "Ruby 2.0 : Keyword arguments", tags: ['ruby']
# => "Ruby 2.0 : Keyword arguments"
# => ['ruby']
# => "post"

devblog tags: ['ruby']
# => ArgumentError (ArgumentError)`
Real world use case
Let's now have a look at the select method from Rails's ActionView::Helpers::FormOptionsHelper. This method takes 5 arguments, including 2 hashes. The first hash relates to generic options about the select (like, does it include a blank option), and another one about html's options (like class, id and so on).

So, it can lead to something like this where we want to add a css class to the select element:

select("post", "person_id", collection, {}, {class: "selectable"})
How many Rails' developers have wondered about the order of those 2 hashes?

It could be a common hash, with a key for options, and another one for html_options.

select("post", "person_id", collection, html_options: {class: "selectable"})
options: {include_blank: true }})
That would be nicer, but this will lead to more complexity in setting default values on options and html_options.

By using Keyword arguments, this would look like:

select("post", "person_id", collection, html_options: {class: "selectable"})
options: {include_blank: true }})
Yes, that would look exactly like the previous example.

The main difference would be on the implementation side.

Usage
module Helpers
  # Just here to allow to call Helpers.select directly. For the sake of the
  # example.
  module_function

  def select(object, method, choices, options = {}, html_options = {})
    options = {include_blank: true}.merge(options)
    [options, html_options]
  end

  def select_one_hash(object, method, choices, options = {})
    options[:options] = {
      include_blank: true,
    }.merge(options.fetch(:options, {}))
    [options[:options], options[:html_options]]
  end

  def select_keyword(object, method, choices, options: {}, html_options: {})
    options = {include_blank: true}.merge(options)
    [options, html_options]
  end
end
This module provides 3 versions of the select method, which returns just the options with the defaults.

Helpers#select takes two options hashes
Helpers#select_one_hash takes one nested hash
Helpers#select_keyword uses Keyword arguments
The only difference between Helpers#select and Helpers#select_keyword can be found in the method declaration where the arguments are declared with a : instead of = for the named argument.

Helpers#select_one_hash has a more complex implementation due to the nested hash.

collection = [["name", 23]] # Choises provided to the select method

puts Helpers.select("post", "person_id", collection, {}, {class: "selectable"})
# => {:include_blank=>true}
# => {:class=>"selectable"}

puts Helpers.select("post", "person_id", collection,
                    {include_blank: false},
                    {class: "selectable"})
# => {:include_blank=>false}
# => {:class=>"selectable"}

puts Helpers.select_one_hash("post", "person_id", collection,
                             html_options: {class: "selectable"})
# => {:include_blank=>true}
# => {:class=>"selectable"}

puts Helpers.select_one_hash("post", "person_id", collection,
                             {html_options: {class: "selectable"},
                             options: {include_blank: false}})
# => {:include_blank=>false}
# => {:class=>"selectable"}

puts Helpers.select_keyword("post", "person_id", collection,
                            html_options: {class: "selectable"})
# => {:include_blank=>true}
# => {:class=>"selectable"}

puts Helpers.select_keyword("post", "person_id", collection,
                            html_options: {class: "selectable"},
                            options: {include_blank: false})
# => {:include_blank=>false}
# => {:class=>"selectable"}
This feature will be available in Ruby 2.0 in less than one month, and worth to be looked at!

And this post closes the Ruby 2.0 preview series.
