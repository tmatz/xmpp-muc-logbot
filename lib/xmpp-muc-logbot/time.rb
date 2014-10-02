#!/usr/bin/env ruby
# coding: utf-8

class Time
  # self 後に sec に指定した秒になる Time を取得します。
  def next_second(sec)
    t = self.round
    u = Time.new(t.year, t.month, t.day, t.hour, t.min, sec)
    if u <= t
       u += 60
    end
    u
  end

  # self 後に sec に指定した秒になる時間までの秒数を取得します。
  def seconds_to_next_second(sec)
    next_second(sec).to_i - self.to_i
  end

  # self 後に min に指定した分になる Time を取得します。
  def next_minite(min)
    t = self.round
    u = Time.new(t.year, t.month, t.day, t.hour, min)
    if u <= t
       u += 60 * 60
    end
    u
  end

  # self 後に min に指定した分になる時間までの秒数を取得します。
  def seconds_to_next_minite(min)
    next_minite(min).to_i - self.to_i
  end

  # self 後に hour に指定した時になる Time を取得します。
  def next_hour(hour)
    t = self.round
    u = Time.new(t.year, t.month, t.day, hour)
    if u <= t
       u += 24 * 60 * 60
    end
    u
  end

  # self 後に hour に指定した時になる時間までの秒数を取得します。
  def seconds_to_next_hour(hour)
    next_hour(hour).to_i - self.to_i
  end
end
