
Pod::Spec.new do |spec|


  spec.name         = "AlphaVideoSwift"
  spec.version      = "0.0.1"
  spec.summary      = "AlphaVideoSwift 直播间MP4格式礼物显示策论，支持本地资源和网上资源"
  spec.swift_version = "5.5"
  spec.description  = <<-DESC
             直播间MP4格式礼物显示策论，支持本地资源和网上资
                   DESC

  spec.homepage     = "https://github.com/kou8910/AlphaVideoSwift"
  spec.license      = { :type => "MIT", :file => "LICENSE" }

  spec.author             = { "len" => "787118083@qq.com" }
 
  spec.platform     = :ios, "10.0"


  spec.ios.deployment_target = "10.0"

  spec.source       = { :git => "https://github.com/kou8910/AlphaVideoSwift.git", :tag => "0.0.1" }


  spec.source_files  = "AlphaVideoSwift", "AlphaVideoSwift/**/*.swift"
  #spec.exclude_files = "Classes/Exclude"

  spec.frameworks = "UIKit","AVFoundation","CoreImage"

  # spec.requires_arc = true


end
