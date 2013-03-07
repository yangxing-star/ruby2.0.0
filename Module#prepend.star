With a release date set to the 24th February 2013, the next major version of Ruby is around the corner. So what Ruby 2.0 will have to offer for its twentieth candle?

Like every new version of a language, this iteration will bring some performance improvements (yay, copy on write), and some new features.

Let's talk about a new method that will add a major change to the Ruby's model object, Module#prepend.

If you already clicked on that link, you can see that the documentation is not really up to date…

Ruby methods lookup

Consider this example :

module FooBar
  def hello
    puts 2
    super
  end
end

class Foo
  def hello
    puts 'hello'
  end
end

class Bar < Foo
  include FooBar
  def hello
    puts 1
    super
  end
end

Bar.new.hello
Ouputs the following:

1
2
"hello"
The Bar class inherits from Foo, and includes the module FooBar. When the method hello is called on a instance of Bar, the following is happening: First, it outputs "1", then it calls the same method with super, but one step above in the hierarchy, which is the module FooBar, prints 2, and calls super.

So, it looks in its own class, then in included modules, and then in class hierarchy.

Seems quite legit, but sometimes, you want a method from a module to take the precedence on a method from the class. There are some solutions to accomplish this task, like alias_method_chain, but it's more a hack than anything - and not really safe.

Module#prepend

Module#prepend does exactly that. Now let's see how it works with a new example (Ruby 2.0 is needed for this one):

module FooBar
  def hello
    puts 2
    super
  end
end

class Foo
  def hello
    puts 'hello'
  end
end

class Bar < Foo
  prepend FooBar

  def hello
    puts 1
    super
  end
end

Bar.new.hello
This code example looks very much like the previous one, except that the module is prepended instead of included. Meaning that methods from these modules will have the precedence over the class.

But with a different output:

2
1
"hello"
Way safer and nicer that alias_method_chain or some monkey patching.

Thanks to Module#prepend, a module for memorization or a cache over some orm could be easily done. I'm pretty sure that prepend will solve some problems in a nice way; and looking forward to use it in a few months.

Coming next in this series: Module#refine.
