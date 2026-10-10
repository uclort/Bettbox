require 'fileutils'

# BETTBOX-CUSTOM: Sparkle 原生更新框固定中文，不修改系统或应用的语言偏好。
module BettboxSparkleLocalization
  def self.apply(resources)
    chinese = File.join(resources, 'zh_CN.lproj', 'Sparkle.strings')
    raise "缺少 Sparkle 简体中文资源：#{chinese}" unless File.file?(chinese)

    translations = Dir.glob(File.join(resources, '*.lproj', 'Sparkle.strings'))
    translations << File.join(resources, 'Base.lproj', 'Sparkle.strings')
    translations.uniq.each do |destination|
      next if destination == chinese

      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(chinese, destination)
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  abort '请指定 Sparkle.framework/Resources 目录' unless ARGV.length == 1
  BettboxSparkleLocalization.apply(ARGV[0])
end
