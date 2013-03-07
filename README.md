
Ruby 2.0 Enumerable::Lazy
March 13, 2012 by Innokenty Mihailov | 20 Comments

My Enumerable::Lazy patch was accepted into ruby trunk few days ago. So, in ruby 2.0, we can go like this:

a = [1,2,3,4,2,5].lazy.map { |x| x * 10 }.select { |x| x > 30 } #=> no evaluation
a.to_a #=> [40, 50], evaluation performed - no intermediate arrays generated.
WHY?
Ruby is awesome language, and while being an imperative one, still allows us to write an elegant, functional programming style code. For example:

data.map(&:split).map(&:reverse)
looks way more readable than this:

data.map { |l| l.split.reverse }
But there’s a serious performance drawback here in the first case: while maping data array twice, unnecessary intermediate array generated. Not a big deal while manipulating tiny arrays, but let’s say you want to parse a huge text file:

File.open("text") do |f|
  f.each.flat_map(&:split).grep(/ruby/)
end
In this case you’d like to avoid unnecessary memory consumption, and that is when laziness come in handy. Having lazy flat_map and grep makes possible to perform evaluation of the whole chain only when we want to get an actual result. Moreover, iterating only once over the original data. That’s the purpose of Lazy enumerator. It overrides several Enumerable methods (map, select, etc) with their lazy analogues.

UPDATE:
Now, after Enumerator::Lazy is almost finished I’ve decided to measure it’s performance. After running some trivial benchmarks I was very upset – it’s almost 4 times (!) slower than the normal arrays are. The point is in blocks that extensively created while chaining enumerator together. See this bug report and comments for more info. In this case the real benefit of Enumerator::Lazy is not as big a it may seem at the very beginning. But take look at this piece of code:

Prime.lazy.select {|x| x % 4 == 3 }.take(10).to_a
instead of this one:

a = []
Prime.each do |x|
  next if x % 4 != 3
  a << x
  break if a.size == 10
end
Now it totally makes sense – when evaluation of the whole chain is too expensive or even impossible (infinite sequences) then laziness is a must if we want to keep our code simple and elegant.

WHEN?
It’s really hard to say who was the first to come up with an idea of lazy enumerations for ruby. Probably this post back in 2008 is among the ground-breakers. The idea is quite simple and based on fact that Enumerators can be chained. Comments were added to enumerator.c file explaining how laziness can be achieved and since that many many many great articles were published. ruby-lang discussion was started more than 3 (!) years ago, and finally Matz vote for implementation by Yataka Hara.

Enumerable::lazy method were proposed. It returns instance of Enumerable::Lazy on the top of the enumerable object, that can be lazy-chained further. C patch was requested and I found myself challenged to make a pull request (I’m in to functional programming recently and interested in ruby internals too). The patch was slightly refactored and accepted a few days ago. It’s landed trunk and will be available since ruby 2.0 (see roadmap).

HOW?
Enumerator (skip if familiar with)
Just to give an insight of what Enumerator can do:

# enumerable as enumerator
enum = [1, 2].each
puts enum.next #=> 1
puts enum.next #=> 2
puts enum.next #=> StopIteration exception raised

# custom enumerable
enum = Enumerator.new do |yielder|
  yielder << 1
  yielder << 2
end
puts enum.next #=> 1
puts enum.next #=> 2
puts enum.next #=> StopIteration exception raised

enum = "xy".enum_for(:each_byte)
enum.each { |b| puts b }
# => 120
# => 121

o = Object.new
def o.each
  yield
  yield 'hello'
  yield [1, 2]
end
enum = o.to_enum
p enum.next #=> nil
p enum.next #=> 'hello'
p enum.next #=> [1, 2]

# chaining enumerators
enum = %w{foo bar baz}.map
puts enum.with_index { |w, i| "#{i}:#{w}" } # => ["0:foo", "1:bar", "2:baz"]

# protect an array from being modified by some_method
a = [1, 2, 3]
some_method(a.enum_for)

# how about this one
[1,2,3].cycle.take(10) #=> [1, 2, 3, 1, 2, 3, 1, 2, 3, 1]
As you might already noticed #to_enum and #enum_for are Kernel module methods, thus available for any object. Examples are taken from enumerator.c directly, you can find more if you want, also check test/ruby/test_enumerator.rb. Well, Enumerator internals probably deserve a separate blog post, but worth to know it’s ruby fibers that makes all this ‘next’ magic possible.

Lazy enumerator
To understand how Enumerable::Lazy works just check this out:

module Enumerable
  class Lazy < Enumerator

    def initialize(obj)
      super() do |yielder|
        obj.each do |val|
          if block_given?
            yield(yielder, val)
          else
            yielder << val
          end
        end
      end
    end

    def map
      Lazy.new(self) do |yielder, val|
        yielder << yield(val)
      end
    end

  end
end

a = Enumerable::Lazy.new([1,2,3])
a = a.map { |x| x * 10 }.map { |x| x - 1 }
puts a.next #=> 9
puts a.next #=> 19
There’s nothing new here – it’s a typical lazy enumerator ruby implementation that can be googled in a second. Same as provided by Yutaka. But did you notice – I’m not using &block as a parameter (to call it as a proc inside each block) here but yielding directly instead. I love this hidden ruby power – you can yield inside another block! block_given? works as expected too. Moreover, you can call self inside another block or make a return from the function. Awesome – we are lucky guys here  . See Yehuda Katz post (another one) to have a better feeling.

The code is self-explanatory, but let’s make it crystal-clear:
the basic idea is to chain enumerators – rather than perform evaluation directly, map returns another Enumerable::Lazy, having previous one as an argument. And only when we need to get an actual result (by calling to_a, next, each with block, take, etc) evaluation performed. To get next value ruby climbs back over this enumerators chain finally getting next value from the actual enumerable (Fig.1). Then this value pops-up back to you, while modified with blocks along the way (in the same order they were applied).

 
Fig.1 Enumerable::Lazy chain
C patch
The C patch – mimics ruby code example. Except the fact that rather than calling super inside lazy_initialize,
I’m allocating generator with a block and then calling enumerator_init passing this new generator as an argument.

In final patch nobu refactored code a little bit – instead of having if-else condition inside a block, he extracted two methods (lazy_init_block_i and lazy_init_block) and moved if-else into lazy_initialize directly. Also, I was passing a ruby array as a block parameter, but it’s better to construct and pass a simple C array. Thus, no need to use rb_ary_entry to get yielder and value inside a block, like this:

static VALUE lazy_map_func(VALUE val, VALUE m, int argc, VALUE *argv)
{
    VALUE result = rb_yield_values2(argc - 1, &argv[1]);

    return rb_funcall(argv[0], id_yield, 1, result);
}
instead of this:

static VALUE lazy_map_func(VALUE val, VALUE m, int argc, VALUE *argv)
{
    VALUE result = rb_funcall(rb_block_proc(), id_call, 1,
    rb_ary_entry(val, 1));

    return rb_funcall(rb_ary_entry(val, 0), id_yield, 1, result);
}
Another lesson for me to learn from ruby core guy. Frankly speaking, I was a total newbie in ruby patching. So it took me two weekends to come up with the (fairly trivial) pull request. First weekend I came up with another crazy pull request – I was storing all blocks as procs inside enumerator itself. And when next value (using Enumerable#next) is requested – all blocks are applied one by one. Lazy map and select were working great, but when trying to adjust Enumerator#each I realized that it’s a road to nowhere (is it?).

Well, you are a tough guy if you made this far, so If you are planning to start patching there are plenty of great articles for you. Also, bonus article showcasing why we should be lazy.

CONCLUSION
We have 5 lazy methods so far – select, map, reject, grep (added by first patch) and flat_map (added later on by shugo). Additionally – rather than doing Enumerable::Lazy.new([1,2,3,4]) you can use handy shortcut [1,2,3,4,5].lazy. If you want to get your hands on – just compile ruby trunk and feel free to play.

UPDATE:
A lot of commits was made into Lazy enumerator during this week. In particular:

Nesting changed: Enumerable::Lazy is now Enumerator::Lazy
Additional lazy methods added, here’s full list so far: map, flat_map, select, reject, grep, zip, take, take_while, drop, drop_while, cycle
Enumerator::Lazy#lazy method added – just returns self
Enumerator::Lazy#force as alias to to_a
Stay tuned!


