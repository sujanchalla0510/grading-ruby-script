require 'rubygems'
require 'mechanize'
require 'nokogiri'
require 'zip'
require 'highline/import'
require 'net/smtp'
require 'mail'
Orca=Class.new do
  #login
  def login
    agent = Mechanize.new { |agent|
    #refreshes after login
    agent.follow_meta_refresh = true
    }
    login_page = agent.get('https://www.cs.usm.edu/moodle/login/index.php')
    print 'USERNAME: '
    user=gets.chomp
    pass = ask("PASSWORD: ") { |q| q.echo = "*" }
    login_form = login_page.form_with(:id => 'login')
    username_field = login_form.field_with(:id => 'username')
    username_field.value = user
    password_field = login_form.field_with(:id => 'password')
    password_field.value = pass
    button = login_form.button_with(:id => 'loginbtn')
    $loggedin_page = login_form.submit(button)
    puts ''
    puts ''
    error_page=$loggedin_page.search("//span[@class='error']").inner_text
    puts error_page
    if error_page.length==0
      puts 'loggedin successfully'
    else
      login()
    end
    homepage()
  end
  
  # homepage
  def homepage()
    puts 'select from the options available'
    myhome = $loggedin_page.link_with(text: 'My home')
    myhome_page = myhome.click
    print '1: '
    puts myhome_page.link_with(text: 'My courses')
    print '2: '
    puts myhome_page.link_with(text: 'Logout')
    puts ''
    print 'enter the option number: '
    choice=gets.chomp
    puts ''
    s=choice.to_i
    if s == 1
      mycourses=myhome_page.link_with(text: 'My courses')
      $mycourses_page=mycourses.click
      $courses=[]
      $mycourses_page.search("//li[@class='type_course depth_3 collapsed contains_branch']").collect{|a|
      $courses << a.inner_text
      puts ($courses.length-1).to_s + " #{$courses.last}"
      }
    elsif s == 2
      logout=myhome_page.link_with(text: 'Logout')
      logout_page=logout.click
      abort("loggedout successfully")
    else
      puts 'please select from the options provided'
      homepage()
    end
    course_select()
  end
  
  # selecting the course 
  def course_select
    puts 'enter your choice :'
    choice=gets.chomp
    puts ''
    s=choice.to_i
    if s < $courses.length
      puts 'select a assignment'
      course=$mycourses_page.link_with(text: $courses[s])
      $course_page=course.click
      $assignments=Array.new(30)
      $i=0
      $course_page.search("//span[@class='instancename']").collect{|span|
      $assignments[$i]=span.inner_text
      puts "#{$i} #{$assignments[$i]}"
      $i+=1
      }
    else
      puts "Please select from the choices available"
      course_select()
    end
    assignment_select()
  end
  
  # selectig the assignment
  def assignment_select
    print 'enter your choice: '
    choice=gets.chomp
    s=choice.to_i
    if s < $i
      $hw_page=$course_page.link_with(text: $assignments[s])
      $asignname=$assignments[s]
      $hwpage=$hw_page.click
      $dhwpage=$hwpage.link_with(text: 'View/grade all submissions')
      $dhwpage1=$dhwpage.click
      form=$dhwpage1.forms.first
      form.field_with(:name => 'jump').options[2].click
      file=form.submit
      file.save_as('Assignment.zip')
      Zip::File.open("Assignment.zip") do |zip_file|
        zip_file.each do |f|
          f.extract(f.name){true}
          filename=f.name 
          destination=File.join(Dir.home,"Assignments/#{$asignname}/#{filename.split(".").first}")
          FileUtils.rm_rf destination if Dir.exist? destination
          FileUtils.mkdir_p destination 
          if(filename.split(".").last=="zip" )
            Zip::File.open(filename) do |zip_file| 
              zip_file.each do |f1|
                f_path=File.join(destination,f1.name)
                FileUtils.mkdir_p(File.dirname(f_path))
                zip_file.extract(f1, f_path){ true } unless File.exist?(f_path)
              end
            end
          else
            FileUtils.cp(filename, destination)
          end
        FileUtils.rm_rf f.name
        end
      end
      FileUtils.rm_rf "Assignment.zip"
    else
      puts "Please select from the choices available"
      assignment_select()
    end
    select_student()
  end
  
  # selecting the student
  def select_student
    puts ''
    puts 'select a student to compile'
    $students=[]
    destination2=File.join(Dir.home,"Assignments/#{$asignname}")
    Dir.foreach("#{destination2}").collect{ |fname|
      $students << fname
    $student_name=$students.last.split("_").first
      puts ($students.length-1).to_s + " #{$student_name}"
    }
    puts ''
    print 'enter your choice :'
    choice=gets.chomp
    puts ''
    s=choice.to_i
    if s < $students.length
      $destination3=File.join(Dir.home,"Assignments/#{$asignname}/#{$students[s]}")
      compilefiles=[]
      $viewfiles=[]
      s=''
      ss=''
      tempfolder=File.join($destination3,"temp")
      FileUtils.rm_rf tempfolder if Dir.exist? tempfolder
      FileUtils.mkdir_p tempfolder 
      Dir.glob("#{$destination3}/**/*.{cpp,h,cxx,txt}") do |f|
        FileUtils.cp(f,tempfolder)
        $viewfiles<<f
        compilefiles<<f.split('/').last
      end
      cfp=''
      compilefiles.each{|cf| 
      cfp=cfp+cf+" "
      }
      puts 'below files are found'
      puts cfp
      system("cd #{tempfolder} && g++ #{cfp} -o execute && execute",:out=>["#{tempfolder}/outlog","w"],:err=>["#{tempfolder}/errlog","w"]) 
      outdata=File.read("#{tempfolder}/outlog")
      if outdata.length==0
        #code to send email to student
        msg = File.read("#{tempfolder}/errlog")
        puts msg
        options = { :address              => "smtp.gmail.com",
        :port                 => 587,
        :domain               => 'your.host.name',
        :user_name            => 'sujankumar0510@gmail.com',
        :password             => 'Sujan0510$',
        :authentication       => 'plain',
        :enable_starttls_auto => true  }
        Mail.defaults do
          delivery_method :smtp, options
        end
        Mail.deliver do
          from      "sujankumar0510@gmail.com"
          to        "sujankumarreddy.challa@eagles.usm.edu"
          subject   "Errors in homework"
          body      "please find the attachment"
          add_file  "#{tempfolder}/errlog"
        end
        puts 'error in compilation mail sent to student'
      else 
        puts outdata
      end
    else
      puts "please enter correct choice"
      select_student()
    end
    select_student_options()
  end
  
  # more options at select_student
  def select_student_options
    puts ''
    print '1 View Files'
    puts ''
    print '2 Grade student'
    puts ''
    print '3 compile another student'
    puts ''
    print 'enter your choice :'
    choice=gets.chomp
    puts ''
    s=choice.to_i
    if s==1
      i=0
      $viewfiles.each{|a| 
      puts "#{i}  #{a}"
      i+=1
      }
      select_student_options2()
    elsif s==2
      print 'enter the grade points : '
      grade=gets.chomp
      puts ''
      studentname= $destination3.split("/").last
      studentname1=studentname.split("_").first
      studentname2="Grade "+studentname1
      dhwpage2= $dhwpage1.link_with(:text=> studentname2)
      gradepage=dhwpage2.click
      gradeform= gradepage.form_with(:id => 'mform1')
      gradeinput=gradeform.field_with(:id => 'id_grade')
      gradeinput.value=grade
      savegrade= gradeform.button_with(:id => 'id_savegrade')
      savedgradepage= gradeform.submit(savegrade)
      puts 'student graded'
      select_student_options()
    elsif s==3
      select_student()
    else
      puts 'please enter correct choice'
      select_student_options()
    end
  end
  
  def select_student_options2()
    puts ''
    print 'enter your choice :'
    choice=gets.chomp
    s=choice.to_i
    if s<$viewfiles.length
      vfdata=File.read("#{$viewfiles[s]}")
      puts vfdata
      select_student_options()
    else
      puts 'please enter correct choice'
      select_student_options2()
    end
  end
end

object=Orca.new
object.login










